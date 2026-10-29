import Foundation
import FoundationModels
import os

/// where an answer came from, shown discreetly under the conversation
nonisolated enum CoachEngineKind: String, Equatable, Sendable {
    /// Apple's server model on Private Cloud Compute, through Foundation Models (iOS 27)
    case privateCloudCompute
    /// the on-device Apple Intelligence model
    case onDevice
    /// fixed sentences from the saved observations; no model ran
    case fallback
    /// Claude Sonnet through the Anthropic API. Debug builds only.
    case claudeDemo

    var label: String {
        switch self {
        case .privateCloudCompute:
            String(localized: "Apple Private Cloud Compute")
        case .onDevice:
            String(localized: "On-device Apple Intelligence")
        case .fallback:
            String(localized: "Saved observations only")
        case .claudeDemo:
            String(localized: "Claude Sonnet (debug demo)")
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
    /// set on coach messages only
    let engine: CoachEngineKind?

    init(id: UUID = UUID(), role: Role, text: String, engine: CoachEngineKind? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.engine = engine
    }
}

/// a language model the coach can talk through. `available` is checked before every use
@MainActor
protocol CoachEngine: AnyObject {
    var kind: CoachEngineKind { get }
    var available: Bool { get }
    /// why this engine cannot answer right now, as one sentence the person can act on; nil when it can
    var unavailableReason: String? { get }
    func prepare(language: CoachLanguage)
    /// selects relevant saved-set labels for `question`; the returned text is never displayed
    func reply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage
    ) async throws -> String
}

/// picks the engine for a turn: the first available one in order, or nil for the fixed text
@MainActor
final class CoachEngineSelector {
    private let engines: [any CoachEngine]

    init(engines: [any CoachEngine]) {
        self.engines = engines
    }

    /// This app is signed without Apple's managed Private Cloud Compute entitlement. Device
    /// availability alone does not authorise PCC, and its framework can trap before throwing.
    /// Use the on-device model until a separately entitled build has been verified.
    static func standard(extra: [any CoachEngine] = []) -> CoachEngineSelector {
        var engines: [any CoachEngine] = extra
        engines.append(OnDeviceCoachEngine())
        return CoachEngineSelector(engines: engines)
    }

    func current() -> (any CoachEngine)? {
        engines.first { $0.available }
    }

    /// when no engine can answer: the first reason an engine gives, logged for the Xcode console
    func unavailableReason() -> String? {
        guard current() == nil else {
            return nil
        }
        return engines.compactMap(\.unavailableReason).first
    }
}

extension CoachEngine {
    var unavailableReason: String? {
        nil
    }

    func prepare(language: CoachLanguage) {}
}

/// reads why Foundation Models cannot run, once per check, and says what to do about it
@MainActor
enum CoachModelAvailability {
    static let log = Logger(subsystem: "ai.mwm.build.challenge.team.08", category: "coach")

    static func reason(for availability: SystemLanguageModel.Availability, engine: String) -> String? {
        switch availability {
        case .available:
            return nil
        case .unavailable(let reason):
            log
                .notice(
                    "\(engine, privacy: .public) unavailable: \(String(describing: reason), privacy: .public)"
                )
            switch reason {
            case .deviceNotEligible:
                return String(
                    localized: "This iPhone cannot run Apple Intelligence, so the coach answers from Finn's records only."
                )
            case .appleIntelligenceNotEnabled:
                return String(
                    localized: "Turn on Apple Intelligence in Settings > Apple Intelligence & Siri, and the coach will pick the sets for you."
                )
            case .modelNotReady:
                return String(
                    localized: "Apple Intelligence is still downloading its model. Until then the coach answers from Finn's records only."
                )
            @unknown default:
                return String(
                    localized: "No language model is available right now, so the coach answers from Finn's records only."
                )
            }
        }
    }
}

/// runs one turn: the model selects at most two saved sets, then Finn renders recorded facts
/// invalid selections, errors and timeouts use fixed text. No model-authored advice is displayed.
@MainActor
final class CoachResponder {
    private let selector: CoachEngineSelector
    private let timeout: Duration
    private let generation = ModelGenerationGate<String>()
    let language: CoachLanguage

    init(
        selector: CoachEngineSelector,
        timeout: Duration = .seconds(20),
        language: CoachLanguage = .current()
    ) {
        self.selector = selector
        self.timeout = timeout
        self.language = language
    }

    var currentEngineKind: CoachEngineKind {
        selector.current()?.kind ?? .fallback
    }

    /// why no model answers, when none does
    var unavailableReason: String? {
        selector.unavailableReason()
    }

    func prepare() {
        selector.current()?.prepare(language: language)
    }

    func answer(_ question: String, context: CoachContext, history: [CoachMessage]) async -> CoachMessage {
        let fallback = CoachMessage(
            role: .coach,
            text: CoachFallback.reply(
                to: question,
                context: context,
                language: language
            ),
            engine: .fallback
        )
        guard
            !Task.isCancelled, !context.isEmpty,
            let engine = selector.current() else {
            return fallback
        }
        let generated = await generation.response(timeout: timeout) { [language] in
            try await engine.reply(to: question, context: context, history: history, language: language)
        }
        if generated?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "NONE" {
            return CoachMessage(
                role: .coach,
                text: CoachFallback.noRelevantAnswer(language: language),
                engine: .fallback
            )
        }
        guard let generated, let selected = CoachAnswerCheck.selectedFacts(in: generated, for: context)
        else {
            return fallback
        }
        let recordedAnswer = selected.map { CoachFallback.summary(of: $0, language: language) }
            .joined(separator: " ")
        return CoachMessage(
            role: .coach,
            text: recordedAnswer,
            engine: engine.kind
        )
    }

}

/// shared by the two Foundation Models engines: instructions, the context, then the turn
@MainActor
enum FoundationModelsCoachPrompt {
    static let maximumQuestionCharacters = 2_000
    static let maximumPromptCharacters = 8_000
    static func instructions(language: CoachLanguage) -> String {
        // instructions contain only trusted app rules. Saved observations and onboarding answers
        // are data in the prompt, never higher-priority instructions to the model
        CoachInstructions.text(language: language)
    }

    /// the earlier turns as text, so a fresh session still knows the conversation. Kept short:
    /// the on-device model has a small window
    static func prompt(question: String, context: CoachContext, history: [CoachMessage]) -> String {
        var sections: [String] = []
        if let note = context.preferencesNote, !note.isEmpty {
            sections.append("Person's stated preferences:\n" + String(note.prefix(500)))
        }
        sections.append("Saved sets, oldest first:\n" + context.boundedPromptText(maximumCharacters: 4_000))
        let recent = history.suffix(4)
        if !recent.isEmpty {
            let lines = recent.map { message in
                (message.role == .person ? "Person: " : "Coach: ") + String(message.text.prefix(250))
            }
            sections.append("Earlier in this conversation:\n" + lines.joined(separator: "\n"))
        }
        sections.append("Person now asks: " + String(question.prefix(maximumQuestionCharacters)))
        return sections.joined(separator: "\n\n")
    }

    static func labels(for numbers: [Int], context: CoachContext) -> String? {
        guard
            (1 ... 2).contains(numbers.count), Set(numbers).count == numbers.count,
            numbers.allSatisfy(context.knownNumbers.contains) else {
            return nil
        }
        return numbers.map { "Set \($0)" }.joined(separator: ", ")
    }
}

@Generable
private struct AppleCoachSelection {
    @Guide(
        description: "Zero, one, or two numbered saved sets relevant to the person's question; use an empty list when no set supports an answer.",
        .count(0 ... 2)
    )
    var setNumbers: [Int]
}

@MainActor
final class OnDeviceCoachEngine: CoachEngine {
    let kind: CoachEngineKind = .onDevice
    private var preparedSession: LanguageModelSession?
    private var preparedLanguage: CoachLanguage?

    func prepare(language: CoachLanguage) {
        guard available, SystemLanguageModel.default.supportsLocale(language.locale) else {
            return
        }
        guard preparedSession == nil || preparedLanguage != language else {
            return
        }
        let session = makeSession(language: language)
        session.prewarm()
        preparedSession = session
        preparedLanguage = language
    }

    private func makeSession(language: CoachLanguage) -> LanguageModelSession {
        LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: FoundationModelsCoachPrompt.instructions(language: language)
        )
    }

    var available: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    var unavailableReason: String? {
        CoachModelAvailability.reason(
            for: SystemLanguageModel.default.availability,
            engine: "On-device model"
        )
    }

    func reply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage
    ) async throws -> String {
        guard available, SystemLanguageModel.default.supportsLocale(language.locale) else {
            throw CoachGenerationError.unavailable
        }
        try Task.checkCancellation()
        let session = preparedLanguage == language
            ? preparedSession ?? makeSession(language: language)
            : makeSession(language: language)
        // Each turn owns its session; prewarming must never reuse an active transcript.
        preparedSession = nil
        preparedLanguage = nil
        let response = try await session.respond(
            to: FoundationModelsCoachPrompt.prompt(question: question, context: context, history: history),
            generating: AppleCoachSelection.self,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 128)
        )
        return FoundationModelsCoachPrompt.labels(for: response.content.setNumbers, context: context) ?? "NONE"
    }
}

private enum CoachGenerationError: Error {
    case unavailable
}

@available(iOS 27, *)
@MainActor
final class PrivateCloudComputeCoachEngine: CoachEngine {
    let kind: CoachEngineKind = .privateCloudCompute
    private let model = PrivateCloudComputeLanguageModel()

    var available: Bool {
        if case .available = model.availability {
            return true
        }
        return false
    }

    /// PCC logs its own reason; the sentence for the person comes from the on-device model, whose
    /// reason (Apple Intelligence off, model downloading) is the one they can act on
    var unavailableReason: String? {
        if case .unavailable(let reason) = model.availability {
            CoachModelAvailability.log
                .notice("Private Cloud Compute unavailable: \(String(describing: reason), privacy: .public)")
        }
        return CoachModelAvailability.reason(
            for: SystemLanguageModel.default.availability,
            engine: "On-device model"
        )
    }

    func reply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage
    ) async throws -> String {
        let session = LanguageModelSession(
            model: model,
            instructions: FoundationModelsCoachPrompt
                .instructions(language: language)
        )
        let response = try await session.respond(
            to: FoundationModelsCoachPrompt.prompt(question: question, context: context, history: history),
            generating: AppleCoachSelection.self
        )
        return FoundationModelsCoachPrompt.labels(for: response.content.setNumbers, context: context) ?? "NONE"
    }
}
