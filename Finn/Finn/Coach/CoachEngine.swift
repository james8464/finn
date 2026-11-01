import Foundation
import FoundationModels
import os

/// where an answer came from, shown discreetly under the conversation
nonisolated enum CoachEngineKind: String, Codable, Equatable, Sendable {
    /// Apple's server model on Private Cloud Compute, through Foundation Models (iOS 27)
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
                    localized: "Turn on Apple Intelligence in Settings > Apple Intelligence & Siri to chat with the coach."
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
        guard !Task.isCancelled, let engine = selector.current() else {
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

/// one turn as the model reads it: the rules and what Finn knows about the person, the earlier
/// messages as real turns, then the person's new message. A small model follows a conversation
/// far better as turns than as quoted text, and reads the memory once instead of every message
nonisolated struct CoachPrompt: Equatable, Sendable {
    /// the rules, then the onboarding answers and the saved sets
    let instructions: String
    /// earlier messages, oldest first, alternating and starting with the person
    let turns: [CoachMessage]
    /// the message to answer now
    let question: String

    /// the same turn for a Foundation Models session
    var transcript: Transcript {
        var entries: [Transcript.Entry] = [.instructions(Transcript.Instructions(
            segments: Self.segments(instructions),
            toolDefinitions: []
        ))]
        for turn in turns {
            let segments = Self.segments(turn.text)
            entries.append(turn.role == .person
                ? .prompt(Transcript.Prompt(segments: segments))
                : .response(Transcript.Response(assetIDs: [], segments: segments)))
        }
        return Transcript(entries: entries)
    }

    private static func segments(_ text: String) -> [Transcript.Segment] {
        [.text(Transcript.TextSegment(content: text))]
    }
}

/// shared by the Foundation Models engines and the Claude demo. Every turn starts a fresh session
/// from the saved state, so the model rereads the whole memory each time and a changed answer or a
/// new set reaches the next reply
@MainActor
enum FoundationModelsCoachPrompt {
    static let maximumQuestionCharacters = 2_000
    /// the whole turn when the model's window is unknown: what fits the 8,192-token on-device window
    nonisolated static let maximumPromptCharacters = 18_000
    /// a dozen short answers; the limit only stops a pasted essay
    static let profileCharacters = 1_500
    static let setCharacters = 4_000
    /// one earlier message: about the longest reply the model writes
    static let messageCharacters = 1_500
    static let maximumResponseTokens = 350
    /// on the low side: chat text measured about 4 characters a token, dates and counts under 3
    static let charactersPerToken = 2.5

    static var options: GenerationOptions {
        GenerationOptions(temperature: 0.7, maximumResponseTokens: maximumResponseTokens)
    }

    /// the characters a turn can use in a model's window, once the reply and a margin are counted
    static func characterBudget(contextSize: Int) -> Int {
        max(0, Int(Double(contextSize - maximumResponseTokens - 256) * charactersPerToken))
    }

    /// the app's rules alone: trusted text, never the person's data
    static func instructions(language: CoachLanguage) -> String {
        CoachInstructions.text(language: language)
    }

    /// the rules and the memory always; then as many of the latest messages as the rest of
    /// `maximumCharacters` holds, so a long conversation forgets its oldest turns first
    static func make(
        question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage,
        maximumCharacters: Int = maximumPromptCharacters
    ) -> CoachPrompt {
        let previous = history.last { $0.role == .person }?.text ?? ""
        let sets = max(setsNeeded(for: question), setsNeeded(for: previous))
        let instructions = instructions(language: language) + "\n\n"
            + memory(context: context, language: language, sets: sets)
        let question = String(question.prefix(maximumQuestionCharacters))
        return CoachPrompt(
            instructions: instructions,
            turns: turns(history, maximumCharacters: maximumCharacters - instructions.count - question.count),
            question: question
        )
    }

    /// what Finn knows: the onboarding answers, then the saved sets with the latest first. Set
    /// labels are in the app's language, so a French reply says "Série 8" by itself.
    /// The on-device model reads a list of sets poorly: with "Set 8" in view during small talk it
    /// offered saved sets as workouts to do, and with several listed it often took the one before
    /// for the last. So it sees no set for small talk, the latest alone for a question about the
    /// last session, and the list only to compare sets or to look at a numbered one
    static func memory(context: CoachContext, language: CoachLanguage, sets: SetsNeeded) -> String {
        var sections: [String] = []
        if let profile = context.profile, !profile.isEmpty {
            sections.append("About the person, from their onboarding answers:\n" + profile.prefix(profileCharacters))
        }
        let heading = "Saved sets, recorded with the camera. Workouts you suggest in this chat are not saved sets.\n"
        if context.isEmpty {
            sections.append("Saved sets: no saved sets yet.")
        } else {
            switch sets {
            case .none:
                sections.append("Saved sets: they have recorded sets with Finn. The details come with questions about their training.")
            case .latest:
                sections.append(heading + context.memoryText(maximumCharacters: setCharacters, setWord: language.setWord, latestOnly: true))
            case .all:
                sections.append(heading + context.memoryText(maximumCharacters: setCharacters, setWord: language.setWord))
            }
        }
        return sections.joined(separator: "\n\n")
    }

    /// how much of the saved sets a turn needs
    nonisolated enum SetsNeeded: Int, Comparable, Sendable {
        case none, latest, all

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// what a message asks about their recorded training, in English, French or Spanish: a
    /// comparison or a numbered set needs every set; the last session, reps, technique or what to
    /// work on next needs the latest. It covers the suggested questions and the analysis card
    nonisolated static func setsNeeded(for message: String) -> SetsNeeded {
        let text = message.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
        let all = #"(\bsets?|serie)\s*#?\s*\d|\bsets\b|series|progres|improv|better|worse|compar|chang|cambi|"#
            + #"evol|analy|bilan|mieux|mejor|peor|over time|au fil|trend"#
        if text.range(of: all, options: .regularExpression) != nil {
            return .all
        }
        let latest = #"\bset\b|serie|\brep|\blast\b|latest|dernier|derniere|ultim|record|enregistr|"#
            + #"technique|tecnica|posture|postura|next time|prochaine fois|proxima vez"#
        return text.range(of: latest, options: .regularExpression) != nil ? .latest : .none
    }

    /// the latest whole messages that fit, as alternating turns that start with the person and
    /// end with Finn. The app's fixed greeting is left out: the model did not write it, and
    /// rereading its set summary made replies circle back to it
    private static func turns(_ history: [CoachMessage], maximumCharacters: Int) -> [CoachMessage] {
        var merged: [CoachMessage] = []
        for message in history where message.role == .person || message.engine != nil {
            let text = String(message.text.prefix(messageCharacters))
            if let last = merged.last, last.role == message.role {
                merged[merged.count - 1] = CoachMessage(
                    id: last.id, role: last.role, text: last.text + "\n" + text, engine: last.engine, sentAt: last.sentAt
                )
            } else {
                merged.append(CoachMessage(
                    id: message.id, role: message.role, text: text, engine: message.engine, sentAt: message.sentAt
                ))
            }
        }
        // a question left unanswered is asked again now
        if merged.last?.role == .person {
            merged.removeLast()
        }
        var remaining = maximumCharacters
        var kept: [CoachMessage] = []
        for message in merged.reversed() {
            guard message.text.count <= remaining else {
                break
            }
            kept.append(message)
            remaining -= message.text.count
        }
        kept.reverse()
        if kept.first?.role == .coach {
            kept.removeFirst()
        }
        return kept
    }
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

    /// loads the model before the first message; each turn then starts its own session
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
        try await streamReply(to: question, context: context, history: history, language: language) { _ in }
    }

    func streamReply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        guard available, SystemLanguageModel.default.supportsLocale(language.locale) else {
            throw CoachGenerationError.unavailable
        }
        try Task.checkCancellation()
        // the prewarmed session only loaded the model; this turn starts from its own transcript
        preparedSession = nil
        preparedLanguage = nil
        // as much of the conversation as this model's window holds
        let prompt = FoundationModelsCoachPrompt.make(
            question: question,
            context: context,
            history: history,
            language: language,
            maximumCharacters: FoundationModelsCoachPrompt.characterBudget(
                contextSize: SystemLanguageModel.default.contextSize
            )
        )
        do {
            return try await stream(prompt, onPartial: onPartial)
        } catch let error as LanguageModelError {
            // the safety check sometimes stops a harmless reply, even one to "ok", before it
            // starts; a second pass usually goes through. A refusal is the model's own choice
            guard case .guardrailViolation = error else {
                throw error
            }
            CoachModelAvailability.log.notice("Guardrail stopped a coach reply; trying once more")
            return try await stream(prompt, onPartial: onPartial)
        }
    }

    private func stream(_ prompt: CoachPrompt, onPartial: @escaping @MainActor (String) -> Void) async throws -> String {
        let session = LanguageModelSession(model: SystemLanguageModel.default, transcript: prompt.transcript)
        var written = ""
        for try await snapshot in session.streamResponse(to: prompt.question, options: FoundationModelsCoachPrompt.options) {
            try Task.checkCancellation()
            written = snapshot.content
            onPartial(written)
        }
        return written
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
        let prompt = FoundationModelsCoachPrompt.make(
            question: question, context: context, history: history, language: language
        )
        let session = LanguageModelSession(model: model, transcript: prompt.transcript)
        let response = try await session.respond(to: prompt.question, options: FoundationModelsCoachPrompt.options)
        return response.content
    }
}
