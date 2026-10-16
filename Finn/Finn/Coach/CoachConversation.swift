import Foundation
import Observation

/// the state behind the Coach screen: the saved sets as context, the turns, and the engine in use
@MainActor
@Observable
final class CoachConversation {
    private(set) var messages: [CoachMessage] = []
    private(set) var isAnswering = false
    private(set) var context: CoachContext
    private let responder: CoachResponder

    init(history: [WorkoutSessionSummary], responder: CoachResponder) {
        self.context = CoachContext.make(history: history)
        self.responder = responder
        messages = [CoachMessage(role: .coach,
                                 text: Self.opening(for: context, engine: responder.currentEngineKind,
                                                    language: responder.language),
                                 engine: responder.currentEngineKind)]
    }

    /// the app's coach: the standard engine order, with the Claude demo first in Debug builds
    convenience init(history: [WorkoutSessionSummary]) {
        var extra: [any CoachEngine] = []
        #if DEBUG
        // synthetic UI tours must not call a live model service. An unsigned iOS 27
        // simulator can advertise PCC as available, then trap inside FoundationModels
        if ProcessInfo.processInfo.arguments.contains("-finn-ui-demo") || ProcessInfo.processInfo.arguments.contains("-finn-presentation-capture") {
            self.init(history: history, responder: CoachResponder(selector: CoachEngineSelector(engines: [])))
            return
        }
        extra.append(ClaudeDemoCoachEngine())
        #endif
        self.init(history: history, responder: CoachResponder(selector: .standard(extra: extra)))
    }

    /// which engine would answer the next question
    var engineKind: CoachEngineKind { responder.currentEngineKind }

    /// why no model answers, when none does: a sentence the person can act on
    var engineNote: String? { responder.unavailableReason }

    /// the saved sets changed (a new set, a deletion): the coach reads them again
    func refresh(history: [WorkoutSessionSummary]) {
        context = CoachContext.make(history: history)
    }

    func send(_ text: String) async {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering else { return }
        let earlier = messages
        messages.append(CoachMessage(role: .person, text: question))
        isAnswering = true
        defer { isAnswering = false }
        let answer = await responder.answer(question, context: context, history: earlier)
        messages.append(answer)
    }

    /// questions the person can tap, so the demo does not start from a blank field
    var suggestedQuestions: [String] {
        guard let latest = context.latest else { return [] }
        switch responder.language {
        case .english:
            return ["How did set \(latest.number) go?",
                    "What should I keep in mind next time?",
                    "What changed across my last sets?"]
        case .french:
            return ["Comment s'est passée la série \(latest.number) ?",
                    "À quoi faire attention la prochaine fois ?",
                    "Qu'est-ce qui a changé sur mes dernières séries ?"]
        case .spanish:
            return ["¿Cómo fue la serie \(latest.number)?",
                    "¿En qué debería fijarme la próxima vez?",
                    "¿Qué cambió en mis últimas series?"]
        }
    }

    private static func opening(for context: CoachContext, engine: CoachEngineKind,
                                language: CoachLanguage) -> String {
        CoachFallback.opening(context: context, language: language)
    }
}
