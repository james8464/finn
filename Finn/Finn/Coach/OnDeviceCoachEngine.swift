import Foundation
import FoundationModels
import os

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
