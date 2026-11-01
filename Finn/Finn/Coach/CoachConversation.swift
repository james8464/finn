import Foundation
import Observation

/// the state behind the Coach screen: the saved sets as context, the turns, and the engine in use
@MainActor
@Observable
final class CoachConversation {
    private(set) var messages: [CoachMessage] = []
    private(set) var isAnswering = false
    /// the coach's reply as the model writes it; nil until its first words arrive
    private(set) var draftReply: String?
    /// the turn allowed to update `draftReply`, so a late word from an earlier turn is ignored
    private var currentTurn: UUID?
    private(set) var context: CoachContext
    private let responder: CoachResponder
    /// where the turns are kept between launches; nil keeps them for this screen only
    private let transcript: CoachTranscriptStore?
    /// a thread that is never cleared, like a messaging app: the most messages kept, months of
    /// chat, so the saved thread stays small. The opening greeting always stays, as it heads the
    /// screen. The model rereads only the latest that fit its window
    static let maximumMessages = 1_000

    init(
        history: [WorkoutSessionSummary],
        responder: CoachResponder,
        profile: String? = nil,
        transcript: CoachTranscriptStore? = nil
    ) {
        self.context = CoachContext.make(history: history, profile: profile)
        self.responder = responder
        self.transcript = transcript
        // a fresh greeting from the latest sets, then the conversation where it was left
        messages = [CoachMessage(
            role: .coach,
            text: CoachFallback.opening(context: context, language: responder.language)
        )] + (transcript?.turns ?? [])
    }

    /// the app's coach: the standard engine order, with the Claude demo first in Debug builds
    convenience init(
        history: [WorkoutSessionSummary],
        profile: String? = nil,
        transcript: CoachTranscriptStore? = nil
    ) {
        var extra: [any CoachEngine] = []
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-finn-ui-native-coach") {
                self.init(
                    history: history,
                    responder: CoachResponder(selector: .standard()),
                    profile: profile,
                    transcript: transcript
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
                    profile: profile,
                    transcript: transcript
                )
                return
            }
            extra.append(ClaudeDemoCoachEngine())
        #endif
        self.init(
            history: history,
            responder: CoachResponder(selector: .standard(extra: extra)),
            profile: profile,
            transcript: transcript
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

    /// the saved sets or the onboarding answers changed: the coach reads them again
    func refresh(history: [WorkoutSessionSummary], profile: String?) {
        let updated = CoachContext.make(history: history, profile: profile)
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
        let turn = UUID()
        currentTurn = turn
        draftReply = nil
        isAnswering = true
        defer {
            isAnswering = false
            draftReply = nil
            currentTurn = nil
        }
        let askedContext = context
        let answer = await responder.answer(question, context: askedContext, history: earlier) { [weak self] partial in
            guard let self, self.currentTurn == turn else {
                return
            }
            self.draftReply = partial
        }
        // the conversation was forgotten while the model worked: drop the reply
        guard currentTurn == turn else {
            return
        }
        guard !Task.isCancelled else {
            // stopped mid-reply: keep what the model had written, like any chat. Nothing else
            if answer.engine != .fallback, context == askedContext {
                messages.append(answer)
            }
            remember()
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
        if messages.count > Self.maximumMessages {
            messages.removeSubrange(1 ... messages.count - Self.maximumMessages)
        }
        remember()
    }

    /// keeps the turns for the next launch
    private func remember() {
        transcript?.save(Array(messages.dropFirst()))
    }

    /// back to the greeting alone, as after Delete all data. A reply on its way is dropped
    func forget() {
        currentTurn = nil
        draftReply = nil
        messages = [CoachMessage(
            role: .coach,
            text: CoachFallback.opening(context: context, language: responder.language)
        )]
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
