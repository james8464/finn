import Foundation

/// The facts that must match before two form readings can describe a trend.
nonisolated private struct FormHistoryKey: Hashable {
    let exercise: String
    let side: String
    let view: String
    let rubric: String
    let check: String

    init(_ set: SetSummary, check: FormCheck) {
        exercise = set.exercise.rawValue
        side = set.bodySide.rawValue
        view = set.cameraView.rawValue
        rubric = set.analysis.rubricVersion
        self.check = check.rawValue
    }
}

/// One saved set, reduced to what the coach may talk about. Every field comes from the local
/// history; nothing here is measured or guessed by the coach itself.
nonisolated struct CoachSetFact: Equatable, Identifiable, Sendable {
    /// Position in the context, oldest first, so "Set 3" means the same thing to the model,
    /// the validator and the person. Starts at 1.
    let number: Int
    let id: UUID
    let exerciseName: String
    let repCount: Int
    let capturedAt: Date
    /// The one observation Plumb kept for this set, with its suggested next action.
    let observation: String?
    /// What the set showed, in the words of the result screen.
    let issues: [String]
    /// Comparison with the previous compatible set of the same session, when there was one.
    let comparison: String?
    let partlyVisible: Bool
    /// The one thing to do next, from the same observation, on its own for the advice answers.
    var nextAction: String? = nil

    var label: String { "Set \(number)" }
}

/// The last sets of the local history, as text the coach engines receive and the fallback reads.
nonisolated struct CoachContext: Equatable, Sendable {
    static let defaultLimit = 8

    let facts: [CoachSetFact]

    var isEmpty: Bool { facts.isEmpty }
    var knownNumbers: Set<Int> { Set(facts.map(\.number)) }
    var latest: CoachSetFact? { facts.last }

    /// Builds the context from the saved sessions, keeping the `limit` most recent sets.
    static func make(history: [WorkoutSessionSummary], limit: Int = defaultLimit,
                     now: Date = .now) -> CoachContext {
        struct Pending {
            let set: SetSummary
            let comparison: String?
        }
        var pending: [Pending] = []
        var previousByCheck: [FormHistoryKey: SetSummary] = [:]
        for session in history.sorted(by: { $0.startedAt < $1.startedAt }) {
            let sets = session.sets.sorted { $0.capturedAt < $1.capturedAt }
            var previousInSession: SetSummary?
            for set in sets {
                var comparisons: [String] = []
                if let previousInSession,
                   let compared = SetComparison.compare(previousInSession, set) {
                    comparisons.append(describe(compared, exercise: set.exercise))
                }
                let eligible = FormTrend.eligibleMeasurements(in: set)
                let priorSets = eligible.compactMap { previousByCheck[FormHistoryKey(set, check: $0.check)] }
                    .sorted { $0.capturedAt > $1.capturedAt }
                comparisons += FormTrend.compareLatest(to: set, among: priorSets).map(\.sentence)
                pending.append(Pending(set: set,
                                       comparison: comparisons.isEmpty ? nil : comparisons.joined(separator: " ")))
                previousInSession = set
                for measurement in eligible {
                    previousByCheck[FormHistoryKey(set, check: measurement.check)] = set
                }
            }
        }
        let kept = Array(pending.suffix(limit))
        let facts = kept.enumerated().map { offset, item -> CoachSetFact in
            let set = item.set
            let definition = set.exercise.definition
            var observation: String?
            var nextAction: String?
            if let cue = set.cue {
                observation = [cue.observation, cue.nextAction]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                nextAction = cue.nextAction.isEmpty ? nil : cue.nextAction
            }
            let issues = (set.issues ?? []).map { $0.title(for: definition) }
            return CoachSetFact(number: offset + 1, id: set.id,
                                exerciseName: definition.copy.name,
                                repCount: set.analysis.reps.count,
                                capturedAt: set.capturedAt,
                                observation: observation,
                                issues: issues,
                                comparison: item.comparison,
                                partlyVisible: set.partlyVisible ?? false,
                                nextAction: nextAction)
        }
        return CoachContext(facts: facts)
    }

    /// One whole sentence fragment per language, so French never mixes with English words.
    private static func describe(_ comparison: Comparison, exercise: ExerciseKind) -> String {
        let copy = exercise.definition.copy
        switch comparison.rangeDirection {
        case .longer:
            return String(localized: "camera-measured \(copy.rangeNoun) \(copy.moreRange) than the previous set")
        case .shorter:
            return String(localized: "camera-measured \(copy.rangeNoun) \(copy.lessRange) than the previous set")
        case .noClearChange:
            return String(localized: "no clear \(copy.rangeNoun) change against the previous set")
        }
    }

    /// The context as the model reads it: one line per set, oldest first.
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

/// The language the coach speaks: the app's, from the device locale. English unless French.
nonisolated enum CoachLanguage: Equatable, Sendable {
    case english
    case french

    static func current(locale: Locale = .current) -> CoachLanguage {
        locale.language.languageCode?.identifier == "fr" ? .french : .english
    }

    /// How a set is named in an answer, so the person and the validator agree.
    var setWord: String {
        switch self {
        case .english: "Set"
        case .french: "Série"
        }
    }
}

/// The rules every engine receives. The coach rewords measured facts; it never measures.
nonisolated enum CoachInstructions {
    static func text(language: CoachLanguage) -> String {
        switch language {
        case .english: return english
        case .french:
            return english + """

            For a French question, use "Série N" where the saved list says "Set N" (same number).
            """
        }
    }

    static let english = """
        You select saved sets relevant to the person's question. Plumb writes the answer from its \
        recorded facts; your words are never shown to the person.

        Use only the numbered sets under "Saved sets". Select at most two. In a text response, \
        output only their labels separated by a comma, for example "Set 2" or "Set 2, Set 3"; \
        output "NONE" if none answers the question. In a structured response, return their numbers \
        or an empty list. Do not add an explanation, measurements, advice, or other words. \
        No medical advice: do not select a set as proof of injury, safety or diagnosis.
        """
}

/// Sentences built from the saved observations, used when no language model can run. It reads
/// the question for its intent (advice for next time, progress, one set, or a recap) and answers
/// from the recorded facts only; it never invents.
nonisolated enum CoachFallback {
    /// What the person is asking for, guessed from a few words. Recap when nothing matches.
    enum Intent: Equatable {
        case advice, progress, set(Int), recap
    }

    static func intent(of question: String) -> Intent {
        let text = question.lowercased()
            .folding(options: [.diacriticInsensitive], locale: nil)
        if let match = text.firstMatch(of: /(?:set|serie)\s*#?\s*(\d+)/), let number = Int(match.output.1) {
            return .set(number)
        }
        let advice = ["next", "should", "keep in mind", "improve", "work on", "focus", "tip", "advice",
                      "prochain", "faire quoi", "je dois", "attention", "conseil", "ameliorer", "travailler"]
        if advice.contains(where: text.contains) { return .advice }
        let progress = ["change", "progress", "better", "worse", "evol", "compar", "over time", "trend",
                        "chang", "progres", "mieux", "moins bien", "au fil"]
        if progress.contains(where: text.contains) { return .progress }
        return .recap
    }

    static func reply(to question: String, context: CoachContext,
                      language: CoachLanguage = .current()) -> String {
        guard let latest = context.latest else {
            return switch language {
            case .english: "Plumb has no saved set yet, so there is nothing to comment on. Finish a set and come back."
            case .french: "Plumb n'a encore aucune série enregistrée, donc rien à commenter. Finis une série et reviens."
            }
        }
        switch intent(of: question) {
        case .advice:
            return advice(context: context, language: language)
        case .progress:
            return progress(context: context, language: language)
        case .set(let number):
            if let fact = context.facts.first(where: { $0.number == number }) {
                return summary(of: fact, language: language)
            }
            return switch language {
            case .english: "Plumb has no set \(number) in its last \(context.facts.count) saved sets. " + summary(of: latest, language: language)
            case .french: "Plumb n'a pas de série \(number) parmi ses \(context.facts.count) dernières séries. " + summary(of: latest, language: language)
            }
        case .recap:
            var lines = [summary(of: latest, language: language)]
            if context.facts.count > 1 {
                let earlier = context.facts.dropLast().reversed().prefix(2)
                for fact in earlier { lines.append(summary(of: fact, language: language)) }
            }
            return lines.joined(separator: " ")
        }
    }

    /// For each exercise, the latest recorded next action and the sets that showed it.
    static func advice(context: CoachContext, language: CoachLanguage) -> String {
        var lines: [String] = []
        var seen: Set<String> = []
        for fact in context.facts.reversed() where !seen.contains(fact.exerciseName) {
            seen.insert(fact.exerciseName)
            let same = context.facts.filter { $0.exerciseName == fact.exerciseName }
            guard let action = same.last(where: { $0.nextAction != nil })?.nextAction else { continue }
            let numbers = same.filter { $0.nextAction == action }.map(\.number)
            let name = fact.exerciseName.lowercased()
            switch language {
            case .english:
                lines.append("For your \(name): \(action) That is what Plumb saw on \(setList(numbers, language: language)).")
            case .french:
                lines.append("Pour tes \(name) : \(action) C'est ce que Plumb a vu sur \(setList(numbers, language: language)).")
            }
        }
        if lines.isEmpty {
            let clean = context.facts.filter { $0.nextAction == nil && !$0.partlyVisible && $0.issues.isEmpty }
            return switch language {
            case .english:
                clean.isEmpty
                    ? "Plumb recorded no next action on your last \(context.facts.count) sets, so there is nothing to work on yet. Keep measuring from the side and I will have more."
                    : "Nothing to fix: Plumb found no clear pattern on \(setList(clean.map(\.number), language: language)). Keep the same range and tempo."
            case .french:
                clean.isEmpty
                    ? "Plumb n'a noté aucune action sur tes \(context.facts.count) dernières séries, donc rien à travailler pour l'instant. Continue à mesurer de profil et j'en saurai plus."
                    : "Rien à corriger : Plumb n'a trouvé aucun motif net sur \(setList(clean.map(\.number), language: language)). Garde la même amplitude et le même tempo."
            }
        }
        return lines.joined(separator: " ")
    }

    /// Per exercise, reps on the first and the last recorded set, and the last camera comparison.
    static func progress(context: CoachContext, language: CoachLanguage) -> String {
        var lines: [String] = []
        var seen: Set<String> = []
        for fact in context.facts where !seen.contains(fact.exerciseName) {
            seen.insert(fact.exerciseName)
            let same = context.facts.filter { $0.exerciseName == fact.exerciseName }
            guard let first = same.first, let last = same.last else { continue }
            var line: String
            if same.count == 1 {
                line = switch language {
                case .english: "\(fact.exerciseName): one set saved, \(first.repCount) reps on \(language.setWord.lowercased()) \(first.number)."
                case .french: "\(fact.exerciseName) : une seule série enregistrée, \(first.repCount) répétitions sur la série \(first.number)."
                }
            } else {
                line = switch language {
                case .english: "\(fact.exerciseName): \(first.repCount) reps on set \(first.number), \(last.repCount) on set \(last.number)."
                case .french: "\(fact.exerciseName) : \(first.repCount) répétitions sur la série \(first.number), \(last.repCount) sur la série \(last.number)."
                }
            }
            if let comparison = same.last(where: { $0.comparison != nil })?.comparison {
                let tail = switch language {
                case .english: " Last camera comparison: \(comparison)."
                case .french: " Dernière comparaison caméra : \(comparison)."
                }
                line += tail
            }
            lines.append(line)
        }
        return lines.joined(separator: " ")
    }

    /// "set 3", "sets 2 and 3", "sets 6 to 8", or "sets 2, 5 and 8".
    static func setList(_ numbers: [Int], language: CoachLanguage) -> String {
        let sorted = Array(Set(numbers)).sorted()
        let word = language.setWord.lowercased()
        let plural = language == .english ? "sets" : "séries"
        let and = language == .english ? "and" : "et"
        let to = language == .english ? "to" : "à"
        guard let first = sorted.first, let last = sorted.last else { return "" }
        if sorted.count == 1 { return "\(word) \(first)" }
        if sorted.count == 2 { return "\(plural) \(first) \(and) \(last)" }
        if sorted.count == last - first + 1 { return "\(plural) \(first) \(to) \(last)" }
        let head = sorted.dropLast().map(String.init).joined(separator: ", ")
        return "\(plural) \(head) \(and) \(last)"
    }

    /// The opening line shown before the person asks anything.
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

/// Accepts only set labels from a model. The app renders the recorded facts itself; model prose
/// never reaches the user because checking arbitrary advice for factual support is unreliable.
nonisolated enum CoachAnswerCheck {
    static func referencedSetNumbers(in text: String) -> Set<Int> {
        var numbers: Set<Int> = []
        let pattern = /(?:[Ss]et|[Ss][ée]rie)\s*#?\s*(\d+)/
        for match in text.matches(of: pattern) {
            if let number = Int(match.output.1) { numbers.insert(number) }
        }
        return numbers
    }

    static func selectedFacts(in text: String, for context: CoachContext) -> [CoachSetFact]? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count) else { return nil }
        var selected: [CoachSetFact] = []
        for part in parts {
            let label = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let match = label.wholeMatch(of: /(?:[Ss]et|[Ss][ée]rie)\s*#?\s*(\d+)/),
                  let number = Int(match.output.1),
                  let fact = context.facts.first(where: { $0.number == number }),
                  !selected.contains(where: { $0.number == number }) else { return nil }
            selected.append(fact)
        }
        return selected
    }
}
