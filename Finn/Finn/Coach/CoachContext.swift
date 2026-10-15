import Foundation

/// the facts that must match before two form readings can describe a trend
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

/// one saved set, reduced to what the coach may talk about. Every field comes from the local
/// history; nothing here is measured or guessed by the coach itself
nonisolated struct CoachSetFact: Equatable, Identifiable, Sendable {
    /// position in the context, oldest first, so "Set 3" means the same thing to the model,
    /// the validator and the person. Starts at 1.
    let number: Int
    let id: UUID
    let exerciseName: String
    let repCount: Int
    let capturedAt: Date
    /// the one observation Finn kept for this set, with its suggested next action
    let observation: String?
    /// what the set showed, in the words of the result screen
    let issues: [String]
    /// comparison with the previous compatible set of the same session, when there was one
    let comparison: String?
    let partlyVisible: Bool
    /// the one thing to do next, from the same observation, on its own for the advice answers
    var nextAction: String? = nil

    var label: String { "Set \(number)" }
}

/// the last sets of the local history, as text the coach engines receive and the fallback reads
nonisolated struct CoachContext: Equatable, Sendable {
    static let defaultLimit = 8

    let facts: [CoachSetFact]

    var isEmpty: Bool { facts.isEmpty }
    var knownNumbers: Set<Int> { Set(facts.map(\.number)) }
    var latest: CoachSetFact? { facts.last }

    /// Keep complete records and favour recent sets when history exceeds the model's budget.
    /// Truncating the old, unbounded text dropped the newest sets and could cut a fact in half.
    func boundedPromptText(maximumCharacters: Int) -> String {
        guard !facts.isEmpty else { return "No saved sets." }
        var remaining = max(0, maximumCharacters)
        var lines: [String] = []
        for fact in facts.reversed() {
            var line = "\(fact.label): \(fact.exerciseName.prefix(60)), \(fact.repCount) reps, \(fact.capturedAt.formatted(.iso8601))"
            if fact.partlyVisible { line += " | partly visible; no posture advice" }
            if let observation = fact.observation {
                line += " | observation: " + observation.prefix(180)
            }
            if let comparison = fact.comparison {
                line += " | comparison: " + comparison.prefix(160)
            }
            if !fact.issues.isEmpty {
                line += " | showed: " + fact.issues.joined(separator: "; ").prefix(100)
            }
            guard line.count + 1 <= remaining else { break }
            lines.append(line)
            remaining -= line.count + 1
        }
        return lines.reversed().joined(separator: "\n")
    }

    /// builds the context from the saved sessions, keeping the `limit` most recent sets
    static func make(history: [WorkoutSessionSummary], limit: Int = defaultLimit,
                     now: Date = .now) -> CoachContext {
        struct Pending {
            let set: SetSummary
            let comparison: String?
        }
        let retainedCount = max(0, min(limit, 32))
        guard retainedCount > 0 else { return CoachContext(facts: []) }
        // Sessions can overlap. A session's start does not establish when its last set happened.
        let chronologicalSets = history.flatMap(\.sets).sorted { earlier, later in
            if earlier.capturedAt != later.capturedAt {
                return earlier.capturedAt < later.capturedAt
            }
            return earlier.id.uuidString < later.id.uuidString
        }
        let firstRetainedIndex = max(0, chronologicalSets.count - retainedCount)
        var kept: [Pending] = []
        kept.reserveCapacity(min(retainedCount, chronologicalSets.count))
        var previousBySession: [UUID: SetSummary] = [:]
        var previousByCheck: [FormHistoryKey: SetSummary] = [:]
        for (index, set) in chronologicalSets.enumerated() {
            let eligible = FormTrend.eligibleMeasurements(in: set)
            // Older sets supply comparison evidence, but do not need strings or pending facts.
            if index >= firstRetainedIndex {
                var comparisons: [String] = []
                if let previous = previousBySession[set.sessionID],
                   let compared = SetComparison.compare(previous, set) {
                    comparisons.append(describe(compared, exercise: set.exercise))
                }
                let priorSets = eligible.compactMap { previousByCheck[FormHistoryKey(set, check: $0.check)] }
                    .sorted { $0.capturedAt > $1.capturedAt }
                comparisons += FormTrend.compareLatest(to: set, among: priorSets).map(\.sentence)
                kept.append(Pending(set: set,
                                    comparison: comparisons.isEmpty ? nil : comparisons.joined(separator: " ")))
            }
            previousBySession[set.sessionID] = set
            for measurement in eligible {
                previousByCheck[FormHistoryKey(set, check: measurement.check)] = set
            }
        }
        let facts = kept.enumerated().map { offset, item -> CoachSetFact in
            let set = item.set
            let definition = set.exercise.definition
            var observation: String?
            var nextAction: String?
            if set.cueResponse != .notRelevant, let cue = set.cue {
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

    /// one whole sentence fragment per language, so French never mixes with English words
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

    /// the context as the model reads it: one line per set, oldest first
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
    case spanish

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en-GB")
        case .french: Locale(identifier: "fr")
        case .spanish: Locale(identifier: "es")
        }
    }

    static func current(locale: Locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)) -> CoachLanguage {
        switch locale.language.languageCode?.identifier {
        case "fr": .french
        case "es": .spanish
        default: .english
        }
    }

    /// how a set is named in an answer, so the person and the validator agree
    var setWord: String {
        switch self {
        case .english: "Set"
        case .french: "Série"
        case .spanish: "Serie"
        }
    }
}

/// the rules every engine receives. The coach rewords measured facts; it never measures.
nonisolated enum CoachInstructions {
    static func text(language: CoachLanguage) -> String {
        switch language {
        case .english: return english
        case .french:
            return english + """

            For a French question, use "Série N" where the saved list says "Set N" (same number).
            """
        case .spanish:
            return english + """

            For a Spanish question, use "Serie N" where the saved list says "Set N" (same number).
            """
        }
    }

    static let english = """
        You select saved sets relevant to the person's question. Finn writes the answer from its \
        recorded facts; your words are never shown to the person.

        Use only the numbered sets under "Saved sets". Select at most two. In a text response, \
        output only their labels separated by a comma, for example "Set 2" or "Set 2, Set 3"; \
        output "NONE" if none answers the question. In a structured response, return their numbers \
        or an empty list. Do not add an explanation, measurements, advice, or other words. \
        No medical advice: do not select a set as proof of injury, safety or diagnosis.
        """
}

/// sentences built from the saved observations, used when no language model can run. It reads
/// the question for its intent (advice for next time, progress, one set, or a recap) and answers
/// from the recorded facts only; it never invents
nonisolated enum CoachFallback {
    static func noRelevantAnswer(language: CoachLanguage) -> String {
        switch language {
        case .english: "Finn didn't measure that in these saved sets. I can only comment on recorded reps and observations."
        case .french: "Finn n'a pas mesuré cela dans ces séries. Je peux seulement commenter les répétitions et observations enregistrées."
        case .spanish: "Finn no midió eso en estas series guardadas. Solo puedo comentar las repeticiones y observaciones registradas."
        }
    }

    /// what the person is asking for, guessed from a few words. Recap when nothing matches.
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
                      "prochain", "faire quoi", "je dois", "attention", "conseil", "ameliorer", "travailler",
                      "siguiente", "mejorar", "consejo", "trabajar", "deberia", "enfocar"]
        if advice.contains(where: text.contains) { return .advice }
        let progress = ["change", "progress", "better", "worse", "evol", "compar", "over time", "trend",
                        "chang", "progres", "mieux", "moins bien", "au fil", "cambio", "mejor", "peor", "evolucion"]
        if progress.contains(where: text.contains) { return .progress }
        return .recap
    }

    static func reply(to question: String, context: CoachContext,
                      language: CoachLanguage = .current()) -> String {
        guard let latest = context.latest else {
            return switch language {
            case .english: "Finn has no saved set yet, so there is nothing to comment on. Finish a set and come back."
            case .french: "Finn n'a encore aucune série enregistrée, donc rien à commenter. Finis une série et reviens."
            case .spanish: "Finn aún no tiene series guardadas, así que no hay nada que comentar. Termina una serie y vuelve."
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
            case .english: "Finn has no set \(number) in its last \(context.facts.count) saved sets. " + summary(of: latest, language: language)
            case .french: "Finn n'a pas de série \(number) parmi ses \(context.facts.count) dernières séries. " + summary(of: latest, language: language)
            case .spanish: "Finn no tiene la serie \(number) entre sus últimas \(context.facts.count) series guardadas. " + summary(of: latest, language: language)
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

    /// for each exercise, the latest recorded next action and the sets that showed it
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
                lines.append("For your \(name): \(action) That is what Finn saw on \(setList(numbers, language: language)).")
            case .french:
                lines.append("Pour tes \(name) : \(action) C'est ce que Finn a vu sur \(setList(numbers, language: language)).")
            case .spanish:
                lines.append("Para tus \(name): \(action) Eso es lo que Finn observó en \(setList(numbers, language: language)).")
            }
        }
        if lines.isEmpty {
            let clean = context.facts.filter { $0.nextAction == nil && !$0.partlyVisible && $0.issues.isEmpty }
            return switch language {
            case .english:
                clean.isEmpty
                    ? "Finn recorded no next action on your last \(context.facts.count) sets, so there is nothing to work on yet. Keep measuring from the side and I will have more."
                    : "Nothing to fix: Finn found no clear pattern on \(setList(clean.map(\.number), language: language)). Keep the same range and tempo."
            case .french:
                clean.isEmpty
                    ? "Finn n'a noté aucune action sur tes \(context.facts.count) dernières séries, donc rien à travailler pour l'instant. Continue à mesurer de profil et j'en saurai plus."
                    : "Rien à corriger : Finn n'a trouvé aucun motif net sur \(setList(clean.map(\.number), language: language)). Garde la même amplitude et le même tempo."
            case .spanish:
                clean.isEmpty
                    ? "Finn no registró ninguna acción para tus últimas \(context.facts.count) series. Sigue grabando el movimiento y podré decirte más."
                    : "Finn no encontró un patrón claro en \(setList(clean.map(\.number), language: language)). Mantén el mismo recorrido y ritmo."
            }
        }
        return lines.joined(separator: " ")
    }

    /// per exercise, reps on the first and the last recorded set, and the last camera comparison
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
                case .spanish: "\(fact.exerciseName): una serie guardada, \(first.repCount) repeticiones en la serie \(first.number)."
                }
            } else {
                line = switch language {
                case .english: "\(fact.exerciseName): \(first.repCount) reps on set \(first.number), \(last.repCount) on set \(last.number)."
                case .french: "\(fact.exerciseName) : \(first.repCount) répétitions sur la série \(first.number), \(last.repCount) sur la série \(last.number)."
                case .spanish: "\(fact.exerciseName): \(first.repCount) repeticiones en la serie \(first.number), \(last.repCount) en la serie \(last.number)."
                }
            }
            if let comparison = same.last(where: { $0.comparison != nil })?.comparison {
                let tail = switch language {
                case .english: " Last camera comparison: \(comparison)."
                case .french: " Dernière comparaison caméra : \(comparison)."
                case .spanish: " Última comparación de cámara: \(comparison)."
                }
                line += tail
            }
            lines.append(line)
        }
        return lines.joined(separator: " ")
    }

    /// "set 3", "sets 2 and 3", "sets 6 to 8", or "sets 2, 5 and 8"
    static func setList(_ numbers: [Int], language: CoachLanguage) -> String {
        let sorted = Array(Set(numbers)).sorted()
        let word = language.setWord.lowercased()
        let plural: String
        let and: String
        let to: String
        switch language {
        case .english: (plural, and, to) = ("sets", "and", "to")
        case .french: (plural, and, to) = ("séries", "et", "à")
        case .spanish: (plural, and, to) = ("series", "y", "a")
        }
        guard let first = sorted.first, let last = sorted.last else { return "" }
        if sorted.count == 1 { return "\(word) \(first)" }
        if sorted.count == 2 { return "\(plural) \(first) \(and) \(last)" }
        if sorted.count == last - first + 1 { return "\(plural) \(first) \(to) \(last)" }
        let head = sorted.dropLast().map(String.init).joined(separator: ", ")
        return "\(plural) \(head) \(and) \(last)"
    }

    /// the opening line shown before the person asks anything
    static func opening(context: CoachContext, language: CoachLanguage = .current()) -> String {
        guard let latest = context.latest else {
            return switch language {
            case .english: "No saved set yet."
            case .french: "Aucune série enregistrée."
            case .spanish: "Aún no hay series guardadas."
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
                text += " The joints were not always in view, so Finn gave no posture advice."
            } else if !fact.issues.isEmpty {
                text += " It showed: \(fact.issues.joined(separator: ", ").lowercased())."
            } else {
                text += " Finn found no clear pattern in it."
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
                text += " Les articulations n'étaient pas toujours visibles, donc Finn n'a donné aucun conseil de posture."
            } else if !fact.issues.isEmpty {
                text += " Ce qu'elle a montré : \(fact.issues.joined(separator: ", ").lowercased())."
            } else {
                text += " Finn n'y a trouvé aucun motif net."
            }
            if let comparison = fact.comparison {
                text += " Par rapport à la série d'avant : \(comparison)."
            }
            return text
        case .spanish:
            var text = "\(label): \(fact.repCount) repeticiones de \(fact.exerciseName.lowercased())."
            if let observation = fact.observation {
                text += " Observación registrada: \(observation)"
            } else if fact.partlyVisible {
                text += " Las articulaciones no siempre se veían, así que Finn no dio consejos de postura."
            } else if !fact.issues.isEmpty {
                text += " Se observó: \(fact.issues.joined(separator: ", ").lowercased())."
            } else {
                text += " Finn no encontró un patrón claro."
            }
            if let comparison = fact.comparison {
                text += " Frente a la serie anterior: \(comparison)."
            }
            return text
        }
    }
}

/// accepts only set labels from a model. The app renders the recorded facts itself; model prose
/// never reaches the user because checking arbitrary advice for factual support is unreliable
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
