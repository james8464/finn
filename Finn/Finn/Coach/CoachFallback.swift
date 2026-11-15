import Foundation

/// sentences built from the saved observations, used when no language model can run. It reads
/// the question for its intent (advice for next time, progress, one set, or a recap) and answers
/// from the recorded facts only; it never invents
nonisolated enum CoachFallback {
    /// the model's safety rules stopped its reply
    static func declined(language: CoachLanguage) -> String {
        switch language {
        case .english:
            "I can't help with that one. Ask me about your training, your sets or how to get started."
        case .french:
            "Je ne peux pas t'aider sur ce sujet. Pose-moi une question sur ton entraînement, tes séries ou comment démarrer."
        case .spanish:
            "No puedo ayudarte con eso. Pregúntame por tu entrenamiento, tus series o cómo empezar."
        }
    }

    static func noRelevantAnswer(language: CoachLanguage) -> String {
        switch language {
        case .english:
            "Finn didn't measure that in these saved sets. I can only comment on recorded reps and observations."
        case .french:
            "Finn n'a pas mesuré cela dans ces séries. Je peux seulement commenter les répétitions et observations enregistrées."
        case .spanish:
            "Finn no midió eso en estas series guardadas. Solo puedo comentar las repeticiones y observaciones registradas."
        }
    }

    /// what the person is asking for, guessed from a few words. Recap when nothing matches.
    enum Intent: Equatable {
        case advice
        case progress
        case set(Int)
        case recap
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
        if advice.contains(where: text.contains) {
            return .advice
        }
        let progress = ["change", "progress", "better", "worse", "evol", "compar", "over time", "trend",
                        "chang", "progres", "mieux", "moins bien", "au fil", "cambio", "mejor", "peor",
                        "evolucion"]
        if progress.contains(where: text.contains) {
            return .progress
        }
        return .recap
    }

    /// Direct record lookups can be answered verbatim from the saved facts.
    static func recordedRecap(to question: String, context: CoachContext, language: CoachLanguage) -> String? {
        guard let latest = context.latest else {
            return nil
        }
        let text = question.lowercased()
            .folding(options: [.diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        switch text {
        case "my last set", "how did my last set go", "how was my last set",
             "how many reps did i do in my last set",
             "ma derniere serie", "comment s'est passee ma derniere serie",
             "combien de repetitions ai-je faites dans ma derniere serie":
            return summary(of: latest, language: language)
        default:
            return nil
        }
    }

    static func reply(
        to question: String,
        context: CoachContext,
        language: CoachLanguage = .current()
    ) -> String {
        guard let latest = context.latest else {
            return switch language {
            case .english:
                "Let's get started with a workout. Choose one in the Workout tab, then I can help you review your reps and technique after your first set."
            case .french:
                "Commençons par un entraînement. Choisis-en un dans l'onglet Séance ; après ta première série, je pourrai t'aider à revoir tes répétitions et ta technique."
            case .spanish:
                "Empecemos con un entrenamiento. Elige uno en la pestaña Entrenamiento; después de la primera serie, podré ayudarte a revisar tus repeticiones y tu técnica."
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
            case .english:
                "Finn has no set \(number) in its last \(context.facts.count) saved sets. " +
                    summary(
                        of: latest,
                        language: language
                    )
            case .french:
                "Finn n'a pas de série \(number) parmi ses \(context.facts.count) dernières séries. " +
                    summary(
                        of: latest,
                        language: language
                    )
            case .spanish:
                "Finn no tiene la serie \(number) entre sus últimas \(context.facts.count) series guardadas. " +
                    summary(
                        of: latest,
                        language: language
                    )
            }
        case .recap:
            var lines = [summary(of: latest, language: language)]
            if context.facts.count > 1 {
                let earlier = context.facts.dropLast().reversed().prefix(2)
                for fact in earlier {
                    lines.append(summary(of: fact, language: language))
                }
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
            guard let action = same.last(where: { $0.nextAction != nil })?.nextAction else {
                continue
            }
            let numbers = same.filter { $0.nextAction == action }.map(\.number)
            let name = fact.exerciseName.lowercased()
            switch language {
            case .english:
                lines
                    .append(
                        "For your \(name): \(action) That is what Finn saw on \(setList(numbers, language: language))."
                    )
            case .french:
                lines
                    .append(
                        "Pour tes \(name) : \(action) C'est ce que Finn a vu sur \(setList(numbers, language: language))."
                    )
            case .spanish:
                lines
                    .append(
                        "Para tus \(name): \(action) Eso es lo que Finn observó en \(setList(numbers, language: language))."
                    )
            }
        }
        if lines.isEmpty {
            let clean = context.facts
                .filter { $0.nextAction == nil && !$0.partlyVisible && $0.issues.isEmpty }
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
            guard let first = same.first, let last = same.last else {
                continue
            }
            var line: String
            if same.count == 1 {
                line = switch language {
                case .english:
                    "\(fact.exerciseName): one set saved, \(first.repCount) reps on \(language.setWord.lowercased()) \(first.number)."
                case .french:
                    "\(fact.exerciseName) : une seule série enregistrée, \(first.repCount) répétitions sur la série \(first.number)."
                case .spanish:
                    "\(fact.exerciseName): una serie guardada, \(first.repCount) repeticiones en la serie \(first.number)."
                }
            } else {
                line = switch language {
                case .english:
                    "\(fact.exerciseName): \(first.repCount) reps on set \(first.number), \(last.repCount) on set \(last.number)."
                case .french:
                    "\(fact.exerciseName) : \(first.repCount) répétitions sur la série \(first.number), \(last.repCount) sur la série \(last.number)."
                case .spanish:
                    "\(fact.exerciseName): \(first.repCount) repeticiones en la serie \(first.number), \(last.repCount) en la serie \(last.number)."
                }
            }
            if let comparison = same.last(where: { $0.comparison != nil })?.comparison {
                let tail = switch language {
                case .english:
                    " Last camera comparison: \(comparison)."
                case .french:
                    " Dernière comparaison caméra : \(comparison)."
                case .spanish:
                    " Última comparación de cámara: \(comparison)."
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
        case .english:
            (plural, and, to) = ("sets", "and", "to")
        case .french:
            (plural, and, to) = ("séries", "et", "à")
        case .spanish:
            (plural, and, to) = ("series", "y", "a")
        }
        guard let first = sorted.first, let last = sorted.last else {
            return ""
        }
        if sorted.count == 1 {
            return "\(word) \(first)"
        }
        if sorted.count == 2 {
            return "\(plural) \(first) \(and) \(last)"
        }
        if sorted.count == last - first + 1 {
            return "\(plural) \(first) \(to) \(last)"
        }
        let head = sorted.dropLast().map(String.init).joined(separator: ", ")
        return "\(plural) \(head) \(and) \(last)"
    }

    /// the opening line shown before the person asks anything
    static func opening(context: CoachContext, language: CoachLanguage = .current()) -> String {
        guard let latest = context.latest else {
            return switch language {
            case .english:
                "Hi, I'm Finn, your coach. Ask me anything about training, or start a workout and I'll help you review your first set."
            case .french:
                "Salut, moi c'est Finn, ton coach. Pose-moi n'importe quelle question sur l'entraînement, ou lance une séance et je t'aiderai à revoir ta première série."
            case .spanish:
                "Hola, soy Finn, tu entrenador. Pregúntame lo que quieras sobre entrenamiento, o empieza un entrenamiento y te ayudaré a revisar tu primera serie."
            }
        }
        let greeting = switch language {
        case .english:
            "Hi, I'm Finn, your coach. Ask me anything. Your latest set:"
        case .french:
            "Salut, moi c'est Finn, ton coach. Demande-moi ce que tu veux. Ta dernière série :"
        case .spanish:
            "Hola, soy Finn, tu entrenador. Pregúntame lo que quieras. Tu última serie:"
        }
        return greeting + " " + summary(of: latest, language: language)
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
