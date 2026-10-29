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
    /// onboarding answers, kept so a refreshed context still carries them
    private let preferencesNote: String?

    init(history: [WorkoutSessionSummary], responder: CoachResponder, preferencesNote: String? = nil) {
        self.preferencesNote = preferencesNote
        self.context = CoachContext.make(history: history, preferencesNote: preferencesNote)
        self.responder = responder
        messages = [CoachMessage(
            role: .coach,
            text: CoachFallback.opening(context: context, language: responder.language)
        )]
    }

    /// the app's coach: the standard engine order, with the Claude demo first in Debug builds
    convenience init(history: [WorkoutSessionSummary], preferencesNote: String? = nil) {
        var extra: [any CoachEngine] = []
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-finn-ui-native-coach") {
                self.init(
                    history: history,
                    responder: CoachResponder(selector: .standard()),
                    preferencesNote: preferencesNote
                )
                return
            }
            // synthetic UI tours must not call a live model service. An unsigned iOS 27
            // simulator can advertise PCC as available, then trap inside FoundationModels
            if
                ProcessInfo.processInfo.arguments.contains("-finn-presentation-capture") ||
                (ProcessInfo.processInfo.arguments.contains("-finn-ui-demo") &&
                    !ProcessInfo.processInfo.arguments.contains("-finn-ui-native-coach")) {
                self.init(
                    history: history,
                    responder: CoachResponder(selector: CoachEngineSelector(engines: [])),
                    preferencesNote: preferencesNote
                )
                return
            }
            extra.append(ClaudeDemoCoachEngine())
        #endif
        self.init(
            history: history,
            responder: CoachResponder(selector: .standard(extra: extra)),
            preferencesNote: preferencesNote
        )
    }

    /// which engine would answer the next question
    var engineKind: CoachEngineKind {
        responder.currentEngineKind
    }

    /// why no model answers, when none does: a sentence the person can act on
    var engineNote: String? {
        responder.unavailableReason
    }

    func prepare() {
        guard !context.isEmpty, !isAnswering else {
            return
        }
        responder.prepare()
    }

    /// the saved sets changed (a new set, a deletion): the coach reads them again
    func refresh(history: [WorkoutSessionSummary]) {
        let updated = CoachContext.make(history: history, preferencesNote: preferencesNote)
        guard updated != context else {
            return
        }
        context = updated
        if messages.count == 1, let greeting = messages.first {
            messages[0] = CoachMessage(
                id: greeting.id,
                role: .coach,
                text: CoachFallback.opening(
                    context: context,
                    language: responder.language
                )
            )
        }
    }

    func send(_ text: String) async {
        let question = String(text.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(FoundationModelsCoachPrompt.maximumQuestionCharacters))
        guard !question.isEmpty, !isAnswering else {
            return
        }
        let earlier = messages
        messages.append(CoachMessage(role: .person, text: question))
        isAnswering = true
        defer { isAnswering = false }
        let askedContext = context
        let answer = await responder.answer(question, context: askedContext, history: earlier)
        guard !Task.isCancelled else {
            return
        }
        if context == askedContext {
            messages.append(answer)
        } else {
            // History can change while the model is working. Answer from the current records
            // so the question is not left hanging or answered with deleted set details.
            messages.append(CoachMessage(
                role: .coach,
                text: CoachFallback.reply(to: question, context: context, language: responder.language),
                engine: .fallback
            ))
        }
        if messages.count > 40 {
            messages.removeFirst(messages.count - 40)
        }
    }

    /// questions the person can tap, once there are saved sets to talk about. Each one meets a
    /// fallback intent: a recap, the progress, then advice
    var suggestedQuestions: [String] {
        guard context.latest != nil else {
            return []
        }
        switch responder.language {
        case .english:
            return ["How did my last set go?",
                    "What changed across my sets?",
                    "What should I focus on next time?"]
        case .french:
            return ["Comment s'est passée ma dernière série ?",
                    "Qu'est-ce qui a changé sur mes séries ?",
                    "Sur quoi me concentrer la prochaine fois ?"]
        case .spanish:
            return ["¿Cómo fue mi última serie?",
                    "¿Qué cambió en mis series?",
                    "¿En qué debería enfocarme la próxima vez?"]
        }
    }

    /// what the analysis card asks: where the person stands, what to do next, what to avoid
    var analysisRequest: String {
        switch responder.language {
        case .english:
            "Analyze my progression and give me advice: tell me where I stand, what I need to do next and what I need to avoid."
        case .french:
            "Analyse ma progression et donne-moi des conseils : dis-moi où j'en suis, ce que je dois faire ensuite et ce que je dois éviter."
        case .spanish:
            "Analiza mi progresión y dame consejos: dime dónde estoy, qué debo hacer a continuación y qué debo evitar."
        }
    }

}
