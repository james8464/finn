import Foundation
import FoundationModels

/// where an answer came from, shown discreetly under the conversation
nonisolated enum CoachEngineKind: String, Codable, Equatable, Sendable {
    /// Retained to decode transcripts from builds that used Private Cloud Compute.
    case privateCloudCompute
    /// the on-device Apple Intelligence model
    case onDevice
    /// fixed sentences from the saved observations; no model ran
    case fallback
    /// Claude Sonnet through the Anthropic API. Debug builds only.
    case claudeDemo
}

nonisolated struct CoachMessage: Identifiable, Codable, Equatable, Sendable {
    enum Role: String, Codable, Equatable, Sendable {
        case person
        case coach
    }

    let id: UUID
    let role: Role
    let text: String
    /// set on coach messages only
    let engine: CoachEngineKind?
    /// when it was sent; the thread shows its time, and its day when the day changes
    let sentAt: Date

    init(id: UUID = UUID(), role: Role, text: String, engine: CoachEngineKind? = nil, sentAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.engine = engine
        self.sentAt = sentAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, text, engine, sentAt
    }

    /// messages saved before they carried a time are kept, dated when first read again
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        engine = try container.decodeIfPresent(CoachEngineKind.self, forKey: .engine)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt) ?? .now
    }
}

/// a language model the coach talks through. `available` is checked before every use
@MainActor
protocol CoachEngine: AnyObject {
    var kind: CoachEngineKind { get }
    var available: Bool { get }
    /// why this engine cannot answer right now, as one sentence the person can act on; nil when it can
    var unavailableReason: String? { get }
    func prepare(language: CoachLanguage)
    /// the coach's reply to `question`, written by the model and shown to the person as it is
    func reply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage
    ) async throws -> String
    /// the same reply, reporting the text written so far each time it grows. Engines that cannot
    /// stream answer in one go
    func streamReply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage,
        onPartial: @escaping @MainActor (String) -> Void
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

    func streamReply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        try await reply(to: question, context: context, history: history, language: language)
    }
}

/// what one model turn produced
nonisolated enum CoachTurnOutcome: Sendable {
    case text(String)
    /// the model's safety rules stopped it; Finn says so in its own words
    case declined
}

/// the text a model has written so far in the current turn
@MainActor
private final class CoachReplyDraft {
    var text = ""
}

/// runs one turn: the model writes the reply, streamed as it grows. With no model, or when the
/// model fails or times out before writing anything, Finn answers from its saved observations
@MainActor
final class CoachResponder {
    private let selector: CoachEngineSelector
    private let timeout: Duration
    private let generation = ModelGenerationGate<CoachTurnOutcome>()
    let language: CoachLanguage

    init(
        selector: CoachEngineSelector,
        timeout: Duration = .seconds(45),
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

    func answer(
        _ question: String,
        context: CoachContext,
        history: [CoachMessage],
        onPartial: @escaping @MainActor (String) -> Void = { _ in }
    ) async -> CoachMessage {
        guard !Task.isCancelled else {
            return unavailableAnswer(to: question, context: context)
        }
        if let recap = CoachFallback.recordedRecap(to: question, context: context, language: language) {
            return CoachMessage(role: .coach, text: recap, engine: .fallback)
        }
        guard let engine = selector.current() else {
            return unavailableAnswer(to: question, context: context)
        }
        let draft = CoachReplyDraft()
        let outcome = await generation.response(timeout: timeout) { [language] in
            do {
                let text = try await engine.streamReply(
                    to: question,
                    context: context,
                    history: history,
                    language: language
                ) { partial in
                    guard !Task.isCancelled else {
                        return
                    }
                    draft.text = partial
                    onPartial(partial)
                }
                return .text(text)
            } catch where CoachModelErrors.isDeclined(error) {
                return .declined
            }
        }
        switch outcome {
        case .text(let text)?:
            let reply = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !reply.isEmpty {
                return CoachMessage(role: .coach, text: reply, engine: engine.kind)
            }
        case .declined?:
            return CoachMessage(role: .coach, text: CoachFallback.declined(language: language), engine: .fallback)
        case nil:
            break
        }
        // stopped, timed out or failed: keep what the model had already written, else the records
        let written = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !written.isEmpty {
            return CoachMessage(role: .coach, text: written, engine: engine.kind)
        }
        return CoachMessage(
            role: .coach,
            text: CoachFallback.reply(to: question, context: context, language: language),
            engine: .fallback
        )
    }

    /// no model can run: say why, when an engine knows, then answer from the saved observations
    private func unavailableAnswer(to question: String, context: CoachContext) -> CoachMessage {
        let records = CoachFallback.reply(to: question, context: context, language: language)
        let text = selector.unavailableReason().map { $0 + "\n\n" + records } ?? records
        return CoachMessage(role: .coach, text: text, engine: .fallback)
    }
}

/// sorts the errors a model can end a turn with
@MainActor
enum CoachModelErrors {
    /// the model's safety rules stopped the reply, as opposed to a failure worth retrying
    static func isDeclined(_ error: any Error) -> Bool {
        guard let error = error as? LanguageModelError else {
            return false
        }
        switch error {
        case .guardrailViolation, .refusal:
            return true
        default:
            return false
        }
    }
}
