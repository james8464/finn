import Foundation
import FoundationModels
import os

/// Where an answer came from, shown discreetly under the conversation.
nonisolated enum CoachEngineKind: String, Equatable, Sendable {
    /// Apple's server model on Private Cloud Compute, through Foundation Models (iOS 27).
    case privateCloudCompute
    /// The on-device Apple Intelligence model.
    case onDevice
    /// Fixed sentences from the saved observations; no model ran.
    case fallback
    /// Claude Sonnet through the Anthropic API. Debug builds only.
    case claudeDemo

    var label: String {
        switch self {
        case .privateCloudCompute: String(localized: "Apple Private Cloud Compute")
        case .onDevice: String(localized: "On-device Apple Intelligence")
        case .fallback: String(localized: "Saved observations only")
        case .claudeDemo: String(localized: "Claude Sonnet (debug demo)")
        }
    }
}

nonisolated struct CoachMessage: Identifiable, Equatable, Sendable {
    enum Role: Equatable, Sendable {
        case person
        case coach
    }

    let id: UUID
    let role: Role
    let text: String
    /// Set on coach messages only.
    let engine: CoachEngineKind?

    init(id: UUID = UUID(), role: Role, text: String, engine: CoachEngineKind? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.engine = engine
    }
}

/// A language model the coach can talk through. `available` is checked before every use.
@MainActor
protocol CoachEngine: AnyObject {
    var kind: CoachEngineKind { get }
    var available: Bool { get }
    /// Why this engine cannot answer right now, as one sentence the person can act on; nil when it can.
    var unavailableReason: String? { get }
    /// Selects relevant saved-set labels for `question`; the returned text is never displayed.
    func reply(to question: String, context: CoachContext, history: [CoachMessage],
               language: CoachLanguage) async throws -> String
}

/// Picks the engine for a turn: the first available one in order, or nil for the fixed text.
@MainActor
final class CoachEngineSelector {
    private let engines: [any CoachEngine]

    init(engines: [any CoachEngine]) {
        self.engines = engines
    }

    /// The order the product asks for: Private Cloud Compute, then the on-device model.
    /// In Debug, `extra` goes first (the Claude demo) when the person turned it on.
    static func standard(extra: [any CoachEngine] = []) -> CoachEngineSelector {
        var engines: [any CoachEngine] = extra
        if #available(iOS 27, *) {
            engines.append(PrivateCloudComputeCoachEngine())
        }
        engines.append(OnDeviceCoachEngine())
        return CoachEngineSelector(engines: engines)
    }

    func current() -> (any CoachEngine)? {
        engines.first { $0.available }
    }

    /// When no engine can answer: the first reason an engine gives, logged for the Xcode console.
    func unavailableReason() -> String? {
        guard current() == nil else { return nil }
        return engines.compactMap(\.unavailableReason).first
    }
}

extension CoachEngine {
    var unavailableReason: String? { nil }
}

/// Reads why Foundation Models cannot run, once per check, and says what to do about it.
@MainActor
enum CoachModelAvailability {
    static let log = Logger(subsystem: "com.finlearn.plumb", category: "coach")

    static func reason(for availability: SystemLanguageModel.Availability, engine: String) -> String? {
        switch availability {
        case .available:
            return nil
        case .unavailable(let reason):
            log.notice("\(engine, privacy: .public) unavailable: \(String(describing: reason), privacy: .public)")
            switch reason {
            case .deviceNotEligible:
                return String(localized: "This iPhone cannot run Apple Intelligence, so the coach answers from Plumb's records only.")
            case .appleIntelligenceNotEnabled:
                return String(localized: "Turn on Apple Intelligence in Settings > Apple Intelligence & Siri, and the coach will pick the sets for you.")
            case .modelNotReady:
                return String(localized: "Apple Intelligence is still downloading its model. Until then the coach answers from Plumb's records only.")
            @unknown default:
                return String(localized: "No language model is available right now, so the coach answers from Plumb's records only.")
            }
        }
    }
}

/// Runs one turn: the model selects at most two saved sets, then Plumb renders recorded facts.
/// Invalid selections, errors and timeouts use fixed text. No model-authored advice is displayed.
@MainActor
final class CoachResponder {
    private let selector: CoachEngineSelector
    private let timeout: Duration
    let language: CoachLanguage

    init(selector: CoachEngineSelector, timeout: Duration = .seconds(20),
         language: CoachLanguage = .current()) {
        self.selector = selector
        self.timeout = timeout
        self.language = language
    }

    var currentEngineKind: CoachEngineKind {
        selector.current()?.kind ?? .fallback
    }

    /// Why no model answers, when none does.
    var unavailableReason: String? { selector.unavailableReason() }

    func answer(_ question: String, context: CoachContext, history: [CoachMessage]) async -> CoachMessage {
        let fallback = CoachMessage(role: .coach,
                                    text: CoachFallback.reply(to: question, context: context, language: language),
                                    engine: .fallback)
        guard let engine = selector.current() else { return fallback }
        let generated = await withTimeout { [language] in
            try await engine.reply(to: question, context: context, history: history, language: language)
        }
        guard let generated, let selected = CoachAnswerCheck.selectedFacts(in: generated, for: context)
        else { return fallback }
        let recordedAnswer = selected.map { CoachFallback.summary(of: $0, language: language) }
            .joined(separator: " ")
        return CoachMessage(role: .coach, text: recordedAnswer,
                            engine: engine.kind)
    }

    private func withTimeout(_ work: @escaping @MainActor () async throws -> String) async -> String? {
        let stream = AsyncStream<String?>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let generation = Task { @MainActor in
                continuation.yield(try? await work())
                continuation.finish()
            }
            let timer = Task.detached { [timeout] in
                guard (try? await Task.sleep(for: timeout)) != nil else { return }
                continuation.yield(nil)
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                generation.cancel()
                timer.cancel()
            }
        }
        var iterator = stream.makeAsyncIterator()
        return await iterator.next() ?? nil
    }
}

/// Shared by the two Foundation Models engines: instructions, the context, then the turn.
@MainActor
enum FoundationModelsCoachPrompt {
    static func instructions(for context: CoachContext, language: CoachLanguage) -> String {
        CoachInstructions.text(language: language)
            // The first-launch answers (level, goal) set the tone; see `OnboardingProfile.coachNote`.
            + (PlumbPreferences.app.onboardingProfile.coachNote.map { "\n\n" + $0 } ?? "")
            + "\n\nSaved sets, oldest first:\n" + context.promptText()
    }

    /// The earlier turns as text, so a fresh session still knows the conversation. Kept short:
    /// the on-device model has a small window.
    static func prompt(question: String, history: [CoachMessage]) -> String {
        let recent = history.suffix(6)
        guard !recent.isEmpty else { return question }
        let lines = recent.map { message in
            (message.role == .person ? "Person: " : "Coach: ") + message.text
        }
        return "Earlier in this conversation:\n" + lines.joined(separator: "\n") + "\n\nPerson now asks: " + question
    }
}

@MainActor
final class OnDeviceCoachEngine: CoachEngine {
    let kind: CoachEngineKind = .onDevice

    var available: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    var unavailableReason: String? {
        CoachModelAvailability.reason(for: SystemLanguageModel.default.availability, engine: "On-device model")
    }

    func reply(to question: String, context: CoachContext, history: [CoachMessage],
               language: CoachLanguage) async throws -> String {
        let session = LanguageModelSession(model: SystemLanguageModel.default,
                                           instructions: FoundationModelsCoachPrompt.instructions(for: context, language: language))
        let response = try await session.respond(to: FoundationModelsCoachPrompt.prompt(question: question, history: history))
        return response.content
    }
}

@available(iOS 27, *)
@MainActor
final class PrivateCloudComputeCoachEngine: CoachEngine {
    let kind: CoachEngineKind = .privateCloudCompute
    private let model = PrivateCloudComputeLanguageModel()

    var available: Bool {
        if case .available = model.availability { return true }
        return false
    }

    /// PCC logs its own reason; the sentence for the person comes from the on-device model, whose
    /// reason (Apple Intelligence off, model downloading) is the one they can act on.
    var unavailableReason: String? {
        if case .unavailable(let reason) = model.availability {
            CoachModelAvailability.log.notice("Private Cloud Compute unavailable: \(String(describing: reason), privacy: .public)")
        }
        return CoachModelAvailability.reason(for: SystemLanguageModel.default.availability, engine: "On-device model")
    }

    func reply(to question: String, context: CoachContext, history: [CoachMessage],
               language: CoachLanguage) async throws -> String {
        let session = LanguageModelSession(model: model,
                                           instructions: FoundationModelsCoachPrompt.instructions(for: context, language: language))
        let response = try await session.respond(to: FoundationModelsCoachPrompt.prompt(question: question, history: history))
        return response.content
    }
}
