import Foundation
import FoundationModels

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
