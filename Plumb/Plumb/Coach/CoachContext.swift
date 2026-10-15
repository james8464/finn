import Foundation

/// one saved set, reduced to what the coach may talk about. Every field comes from the local
/// history; nothing here is measured or guessed by the coach itself.
nonisolated struct CoachSetFact: Equatable, Identifiable, Sendable {
    /// position in the context, oldest first, so "Set 3" means the same thing to the model,
    /// the validator and the person. Starts at 1.
    let number: Int
    let id: UUID
    let exerciseName: String
    let repCount: Int
    let capturedAt: Date
    /// the one observation Plumb kept for this set, with its suggested next action.
    let observation: String?
    /// what the set showed, in the words of the result screen.
    let issues: [String]
    /// comparison with the previous compatible set of the same session, when there was one.
    let comparison: String?
    let partlyVisible: Bool

    var label: String { "Set \(number)" }
}

/// the last sets of the local history, as text the coach engines receive and the fallback reads.
nonisolated struct CoachContext: Equatable, Sendable {
    static let defaultLimit = 8

    let facts: [CoachSetFact]

    var isEmpty: Bool { facts.isEmpty }
    var knownNumbers: Set<Int> { Set(facts.map(\.number)) }
    var latest: CoachSetFact? { facts.last }

    /// builds the context from the saved sessions, keeping the `limit` most recent sets.
    static func make(history: [WorkoutSessionSummary], limit: Int = defaultLimit,
                     now: Date = .now) -> CoachContext {
        struct Pending {
            let set: SetSummary
            let comparison: String?
        }
        var pending: [Pending] = []
        for session in history.sorted(by: { $0.startedAt < $1.startedAt }) {
            let sets = session.sets.sorted { $0.capturedAt < $1.capturedAt }
            var previous: SetSummary?
            for set in sets {
                var comparison: String?
                if let previous, let compared = SetComparison.compare(previous, set) {
                    comparison = describe(compared, exercise: set.exercise)
                }
                pending.append(Pending(set: set, comparison: comparison))
                previous = set
            }
        }
        let kept = Array(pending.suffix(limit))
        let facts = kept.enumerated().map { offset, item -> CoachSetFact in
            let set = item.set
            let definition = set.exercise.definition
            var observation: String?
            if let cue = set.cue {
                observation = [cue.observation, cue.nextAction]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            let issues = (set.issues ?? []).map { $0.title(for: definition) }
            return CoachSetFact(number: offset + 1, id: set.id,
                                exerciseName: definition.copy.name,
                                repCount: set.analysis.reps.count,
                                capturedAt: set.capturedAt,
                                observation: observation,
                                issues: issues,
                                comparison: item.comparison,
                                partlyVisible: set.partlyVisible ?? false)
        }
        return CoachContext(facts: facts)
    }

    private static func describe(_ comparison: Comparison, exercise: ExerciseKind) -> String {
        let copy = exercise.definition.copy
        switch comparison.rangeDirection {
        case .longer: return "camera-measured \(copy.rangeNoun) \(copy.moreRange) than the previous set"
        case .shorter: return "camera-measured \(copy.rangeNoun) \(copy.lessRange) than the previous set"
        case .noClearChange: return "no clear \(copy.rangeNoun) change against the previous set"
        }
    }

    /// the context as the model reads it: one line per set, oldest first.
    func promptText(calendar: Calendar = .current, timeZone: TimeZone = .current) -> String {
        guard !facts.isEmpty else { return "No saved sets." }
        var formatter = Date.FormatStyle(date: .abbreviated, time: .shortened)
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        return facts.map { fact in
            var parts = ["\(fact.label): \(fact.exerciseName), \(fact.repCount) reps, \(fact.capturedAt.formatted(formatter))"]
            if fact.partlyVisible { parts.append("joints not always in view, so no posture advice") }
            if let observation = fact.observation { parts.append("observation: \(observation)") }
            if !fact.issues.isEmpty { parts.append("showed: \(fact.issues.joined(separator: "; "))") }
            if let comparison = fact.comparison { parts.append("comparison: \(comparison)") }
            return parts.joined(separator: " | ")
        }.joined(separator: "\n")
    }
}

/// the language the coach speaks: the app's, from the device locale. English unless French.
nonisolated enum CoachLanguage: Equatable, Sendable {
    case english
    case french

    static func current(locale: Locale = .current) -> CoachLanguage {
        locale.language.languageCode?.identifier == "fr" ? .french : .english
    }

    /// how a set is named in an answer, so the person and the validator agree.
    var setWord: String {
        switch self {
        case .english: "Set"
        case .french: "Série"
        }
    }
}

/// the rules every engine receives. The coach speaks conversationally, grounded strictly in the
/// recorded facts supplied below. It never invents measurements, never gives medical advice,
/// and always refers back to what Plumb actually captured.
nonisolated enum CoachInstructions {
    static func text(language: CoachLanguage) -> String {
        switch language {
        case .english: return english
        case .french:
            return english + """

            Answer in French. Use "Série N" where the data says "Set N" (same number).
            """
        }
    }

    static let english = """
        You are Plumb's personal coach. You have access to the person's recorded workout sets \
        listed below. Reply conversationally and helpfully, drawing only on the facts in those sets. \
        Do not invent numbers, measurements, or form advice that is not in the data. \
        Keep replies concise — two to four sentences. \
        Do not give medical advice or make injury diagnoses. \
        If the question cannot be answered from the recorded data, say so honestly and briefly.
        """
}

/// fixed sentences built from the saved observations, used when no language model can run.
/// It does not pretend to converse: it reports, and says what it cannot do.
nonisolated enum CoachFallback {
    static func reply(to question: String, context: CoachContext,
                      language: CoachLanguage = .current()) -> String {
        guard let latest = context.latest else {
            return switch language {
            case .english: "Plumb has no saved set yet, so there is nothing to comment on. Finish a set and come back."
            case .french: "Plumb n'a encore aucune série enregistrée, donc rien à commenter. Finis une série et reviens."
            }
        }
        var lines: [String] = []
        let preface = switch language {
        case .english: "Without a language model on this iPhone, I can only repeat what Plumb saved."
        case .french: "Sans modèle de langage sur cet iPhone, je ne peux que répéter ce que Plumb a enregistré."
        }
        lines.append(preface)
        lines.append(summary(of: latest, language: language))
        if context.facts.count > 1 {
            let earlier = context.facts.dropLast().reversed().prefix(2)
            for fact in earlier { lines.append(summary(of: fact, language: language)) }
        }
        return lines.joined(separator: " ")
    }

    /// the opening line shown before the person asks anything.
    static func opening(context: CoachContext, language: CoachLanguage = .current()) -> String {
        guard let latest = context.latest else {
            return switch language {
            case .english: "No saved set yet. Once you finish one, I can go over what Plumb measured."
            case .french: "Aucune série enregistrée pour l'instant. Dès que tu en finis une, je reprends ce que Plumb a mesuré."
            }
        }
        return summary(of: latest, language: language)
    }

    static func summary(of fact: CoachSetFact, language: CoachLanguage = .current()) -> String {
        let label = "\(language.setWord) \(fact.number)"
        switch language {
        case .english:
            var text = "\(label): \(fact.repCount) \(fact.exerciseName.lowercased()) reps."
            if let observation = fact.observation {
                text += " Observation: \(observation)"
            } else if fact.partlyVisible {
                text += " The joints were not always in view, so Plumb gave no posture advice."
            } else if !fact.issues.isEmpty {
                text += " It showed: \(fact.issues.joined(separator: ", ").lowercased())."
            } else {
                text += " Plumb found no clear pattern in it."
            }
            if let comparison = fact.comparison {
                text += " Compared with the set before: \(comparison)."
            }
            return text
        case .french:
            var text = "\(label) : \(fact.repCount) répétitions, \(fact.exerciseName.lowercased())."
            if let observation = fact.observation {
                text += " Observation enregistrée : \(observation)"
            } else if fact.partlyVisible {
                text += " Les articulations n'étaient pas toujours visibles, donc Plumb n'a donné aucun conseil de posture."
            } else if !fact.issues.isEmpty {
                text += " Ce qu'elle a montré : \(fact.issues.joined(separator: ", ").lowercased())."
            } else {
                text += " Plumb n'y a trouvé aucun motif net."
            }
            if let comparison = fact.comparison {
                text += " Par rapport à la série d'avant : \(comparison)."
            }
            return text
        }
    }
}


