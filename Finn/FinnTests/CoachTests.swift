import Foundation
import FoundationModels
import Testing
@testable import Finn

@MainActor
struct CoachTests {
    // MARK: Fixtures

    private func rep(_ number: Int, range: Double = 0.4) -> RepMetric {
        RepMetric(
            number: number,
            startTime: Double(number) * 2,
            endTime: Double(number) * 2 + 1.5,
            relativeRange: range
        )
    }

    private func set(
        session: UUID,
        at date: Date,
        exercise: ExerciseKind = .bodyweightSquat,
        reps: Int = 6,
        range: Double = 0.4,
        cue: Cue? = nil,
        issues: [SetIssue]? = nil,
        partlyVisible: Bool? = nil,
        formMeasurements: [FormMeasurement]? = nil
    ) -> SetSummary {
        SetSummary(
            id: UUID(),
            sessionID: session,
            capturedAt: date,
            bodySide: .left,
            analysis: SetAnalysis(
                reps: (1 ... reps).map { rep($0, range: range) },
                confidence: 0.95,
                rubricVersion: "squat-side-v7"
            ),
            cue: cue,
            cueResponse: .unanswered,
            exercise: exercise,
            cameraView: .side,
            issues: issues,
            formMeasurements: formMeasurements,
            partlyVisible: partlyVisible
        )
    }

    private var rangeCue: Cue {
        Cue(
            kind: .rangeDecreased,
            repNumbers: [5, 6],
            earlierMedian: 0.4,
            laterMedian: 0.3,
            observation: "Your last two reps were shallower than your first two.",
            nextAction: "Try reaching the same depth on every rep."
        )
    }

    private func history() -> [WorkoutSessionSummary] {
        let session = UUID()
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let first = set(session: session, at: start, range: 0.4, issues: [])
        let second = set(
            session: session,
            at: start.addingTimeInterval(300),
            range: 0.3,
            cue: rangeCue,
            issues: [.rangeDropped]
        )
        let later = UUID()
        let third = set(
            session: later,
            at: start.addingTimeInterval(90_000),
            exercise: .pushUp,
            reps: 8,
            issues: [.partlyVisible],
            partlyVisible: true
        )
        return [WorkoutSessionSummary(id: later, startedAt: start.addingTimeInterval(90_000), sets: [third]),
                WorkoutSessionSummary(id: session, startedAt: start, sets: [first, second])]
    }

    // MARK: Context

    @Test func contextKeepsSetsOldestFirstWithObservationsAndComparison() {
        let context = CoachContext.make(history: history())
        #expect(context.facts.count == 3)
        #expect(context.facts.map(\.number) == [1, 2, 3])
        #expect(context.facts[0].exerciseName == "Squat")
        #expect(context.facts[0].observation == nil)
        #expect(context.facts[1]
            .observation ==
            "Your last two reps were shallower than your first two. Try reaching the same depth on every rep.")
        #expect(context.facts[1].comparison?.contains("shorter") == true)
        #expect(context.facts[2].exerciseName == "Push-up")
        #expect(context.facts[2].repCount == 8)
        #expect(context.facts[2].partlyVisible)
        #expect(context.facts[2].issues == ["Joints not always in view"])
        let prompt = context.promptText()
        #expect(prompt.contains("Set 2: Squat, 6 reps"))
        #expect(prompt.contains("observation: Your last two reps"))
        #expect(prompt.contains("Set 3: Push-up, 8 reps"))
    }

    @Test func overlappingSessionsKeepTheActualLatestSetAndItsEarlierComparison() {
        let firstSession = UUID()
        let secondSession = UUID()
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let first = set(session: firstSession, at: start, range: 0.4)
        let latest = set(session: firstSession, at: start.addingTimeInterval(300), range: 0.2)
        let middle = set(session: secondSession, at: start.addingTimeInterval(100), range: 0.5)
        let history = [
            WorkoutSessionSummary(id: firstSession, startedAt: start, sets: [first, latest]),
            WorkoutSessionSummary(id: secondSession, startedAt: middle.capturedAt, sets: [middle])
        ]
        let context = CoachContext.make(history: history, limit: 2)
        #expect(context.facts.map(\.id) == [middle.id, latest.id])
        #expect(context.latest?.comparison?.contains("shorter") == true)
        #expect(CoachContext.make(history: history.reversed(), limit: 2) == context)
    }

    @Test func rejectedObservationIsNotRepeatedAsAdvice() {
        let session = UUID()
        var rejected = set(session: session, at: .now, cue: rangeCue)
        rejected.cueResponse = .notRelevant
        let context = CoachContext.make(history: [
            WorkoutSessionSummary(id: session, startedAt: rejected.capturedAt, sets: [rejected])
        ])
        #expect(context.latest?.observation == nil)
        #expect(context.latest?.nextAction == nil)
        #expect(!context.promptText().contains(rangeCue.nextAction))
        #expect(context.latest?.repCount == 6)
    }

    @Test func contextKeepsOnlyTheMostRecentSets() {
        let session = UUID()
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let sets = (0 ..< 12).map { set(
            session: session,
            at: start.addingTimeInterval(Double($0) * 200),
            reps: $0 + 1
        ) }
        let context = CoachContext.make(
            history: [WorkoutSessionSummary(id: session, startedAt: start, sets: sets)],
            limit: 5
        )
        #expect(context.facts.count == 5)
        #expect(context.facts.map(\.repCount) == [8, 9, 10, 11, 12])
        #expect(context.facts.first?.number == 1)
    }

    @Test func coachCanReportMeasuredFormChangeAcrossSessions() {
        let firstID = UUID()
        let secondID = UUID()
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let first = set(
            session: firstID,
            at: date,
            formMeasurements: [FormMeasurement(
                check: .squatDepth,
                judged: 6,
                faulty: 5,
                typical: 40
            )]
        )
        let second = set(
            session: secondID,
            at: date.addingTimeInterval(90_000),
            formMeasurements: [FormMeasurement(
                check: .squatDepth,
                judged: 6,
                faulty: 1,
                typical: 20
            )]
        )
        let context = CoachContext.make(history: [
            WorkoutSessionSummary(id: secondID, startedAt: second.capturedAt, sets: [second]),
            WorkoutSessionSummary(id: firstID, startedAt: first.capturedAt, sets: [first]),
        ])
        #expect(context.facts.last?.comparison?.contains("down from 5 of 6") == true)
        #expect(CoachFallback.progress(context: context, language: .english).contains("down from 5 of 6"))
    }

    @Test func coachSkipsIncompatibleMeasuredSetForFormTrend() {
        let session = UUID()
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let first = set(
            session: session,
            at: date,
            formMeasurements: [FormMeasurement(
                check: .squatDepth,
                judged: 6,
                faulty: 5,
                typical: 40
            )]
        )
        let obscured = set(
            session: session,
            at: date.addingTimeInterval(100),
            partlyVisible: true,
            formMeasurements: [FormMeasurement(
                check: .squatDepth,
                judged: 6,
                faulty: 5,
                typical: 40
            )]
        )
        let last = set(
            session: session,
            at: date.addingTimeInterval(200),
            formMeasurements: [FormMeasurement(
                check: .squatDepth,
                judged: 6,
                faulty: 1,
                typical: 20
            )]
        )
        let context = CoachContext.make(history: [WorkoutSessionSummary(
            id: session,
            startedAt: date,
            sets: [first, obscured, last]
        )])
        #expect(context.facts.last?.comparison?.contains("down from 5 of 6") == true)
    }

    @Test func coachKeepsLatestPriorForEachFormCheck() {
        let session = UUID()
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let depth = set(
            session: session,
            at: date,
            formMeasurements: [FormMeasurement(
                check: .squatDepth,
                judged: 6,
                faulty: 5,
                typical: 40
            )]
        )
        let chest = set(
            session: session,
            at: date.addingTimeInterval(100),
            formMeasurements: [FormMeasurement(
                check: .squatChestDrop,
                judged: 6,
                faulty: 5,
                typical: 50
            )]
        )
        let latest = set(
            session: session,
            at: date.addingTimeInterval(200),
            formMeasurements: [FormMeasurement(
                check: .squatDepth,
                judged: 6,
                faulty: 1,
                typical: 20
            ),
            FormMeasurement(
                check: .squatChestDrop,
                judged: 6,
                faulty: 1,
                typical: 20
            )]
        )
        let context = CoachContext.make(history: [WorkoutSessionSummary(
            id: session,
            startedAt: date,
            sets: [depth, chest, latest]
        )])
        let comparison = context.facts.last?.comparison ?? ""
        #expect(comparison.contains("depth check flagged"))
        #expect(comparison.contains("chest position check flagged"))
    }

    @Test func emptyHistoryGivesEmptyContextAndHonestFallback() async {
        let context = CoachContext.make(history: [])
        #expect(context.isEmpty)
        #expect(context.promptText() == "No saved sets.")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: []), language: .english)
        let answer = await responder.answer("How am I doing?", context: context, history: [])
        #expect(answer.engine == .fallback)
        #expect(answer.text.contains("Workout tab"))
        #expect(answer.text.contains("first set"))
        let conversation = CoachConversation(history: [], responder: responder)
        #expect(conversation.messages.first?.text.contains("start a workout") == true)
        #expect(conversation.messages.first?.engine == nil, "The fixed greeting did not run a model")
        #expect(conversation.suggestedQuestions.isEmpty)
        #expect(CoachFallback.reply(to: "Des conseils ?", context: context, language: .french)
            .contains("l'onglet Séance"))
        #expect(CoachFallback.reply(to: "¿Qué hago?", context: context, language: .spanish)
            .contains("la pestaña Entrenamiento"))
    }

    // MARK: Engines unavailable

    @Test func unavailableEnginesUseFixedSentencesFromSavedObservations() async {
        let engine = StubCoachEngine(available: false, output: "Set 9 looked great.")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        #expect(responder.currentEngineKind == .fallback)
        let context = CoachContext.make(history: history())
        let answer = await responder.answer("How did I do?", context: context, history: [])
        #expect(answer.engine == .fallback)
        #expect(engine.calls == 0)
        #expect(answer.text.contains("Set 3: 8 push-up reps."))
        #expect(answer.text.contains("Set 2: 6 squat reps. Observation: Your last two reps were shallower"))
        #expect(!answer.text.contains("Set 9"))
    }

    @Test func frenchFallbackSpeaksFrench() async {
        let responder = CoachResponder(selector: CoachEngineSelector(engines: []), language: .french)
        let answer = await responder.answer(
            "Alors ?",
            context: CoachContext.make(history: history()),
            history: []
        )
        #expect(answer.text.contains("Série 3 : 8 répétitions, push-up."))
    }

    @Test func spanishFallbackAndSuggestionsSpeakSpanish() async {
        #expect(CoachLanguage.current(locale: Locale(identifier: "es_ES")) == .spanish)
        let responder = CoachResponder(selector: CoachEngineSelector(engines: []), language: .spanish)
        let context = CoachContext.make(history: history())
        let answer = await responder.answer("¿Cómo fue mi serie?", context: context, history: [])
        #expect(answer.text.contains("Serie"))
        #expect(answer.text.contains("repeticiones"))
        let conversation = CoachConversation(history: history(), responder: responder)
        #expect(conversation.suggestedQuestions.first?.contains("serie") == true)
    }

    // MARK: Simulated engine

    @Test func modelReplyIsShownAsWritten() async {
        let engine = StubCoachEngine(output: "  Hey! Set 2 went well, keep that depth.  ")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let context = CoachContext.make(history: history())
        let answer = await responder.answer("Hi coach, can we talk?", context: context, history: [])
        #expect(answer.engine == .onDevice)
        #expect(answer.text == "Hey! Set 2 went well, keep that depth.")
        #expect(engine.calls == 1)
        #expect(engine.lastInstructionsContext?.facts.count == 3)
    }

    @Test func aDeclinedReplySaysSoInFinnsWords() async {
        let engine = StubCoachEngine(
            output: nil,
            error: LanguageModelError.guardrailViolation(.init(debugDescription: "test"))
        )
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .french)
        let answer = await responder.answer("…", context: CoachContext.make(history: history()), history: [])
        #expect(answer.engine == .fallback)
        #expect(answer.text == CoachFallback.declined(language: .french))
    }

    @Test func streamedWordsReachTheDraftThenTheTranscript() async {
        let engine = StreamingCoachEngine(parts: ["Salut", "Salut ! On peut parler."])
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .french)
        let conversation = CoachConversation(history: [], responder: responder)
        var drafts: [String] = []
        engine.onEachPart = { drafts.append(conversation.draftReply ?? "") }
        await conversation.send("Hey, salut coach, on peut parler ?")
        #expect(drafts == ["Salut", "Salut ! On peut parler."])
        #expect(conversation.messages.last?.text == "Salut ! On peut parler.")
        #expect(conversation.messages.last?.engine == .onDevice)
        #expect(conversation.draftReply == nil)
        #expect(!conversation.isAnswering)
    }

    @Test func aTimeoutKeepsWhatTheModelHadAlreadyWritten() async {
        let engine = StreamingCoachEngine(parts: ["Good question. Squats work"], hangsAfterParts: true)
        let responder = CoachResponder(
            selector: CoachEngineSelector(engines: [engine]),
            timeout: .milliseconds(150),
            language: .english
        )
        let answer = await responder.answer("Why squats?", context: CoachContext(facts: []), history: [])
        #expect(answer.engine == .onDevice)
        #expect(answer.text == "Good question. Squats work")
    }

    @Test func emptyOrFailingAnswerFallsBack() async {
        let empty = StubCoachEngine(output: "   ")
        let context = CoachContext.make(history: history())
        let first = await CoachResponder(selector: CoachEngineSelector(engines: [empty]), language: .english)
            .answer("Hi", context: context, history: [])
        #expect(first.engine == .fallback)
        let failing = StubCoachEngine(output: nil)
        let second = await CoachResponder(
            selector: CoachEngineSelector(engines: [failing]),
            language: .english
        )
        .answer("Hi", context: context, history: [])
        #expect(second.engine == .fallback)
    }

    @Test func slowEngineFallsBackAfterTimeout() async {
        let engine = StubCoachEngine(output: "Set 1 was fine.", delay: .seconds(5))
        let responder = CoachResponder(
            selector: CoachEngineSelector(engines: [engine]),
            timeout: .milliseconds(100),
            language: .english
        )
        let answer = await responder.answer("Hi", context: CoachContext.make(history: history()), history: [])
        #expect(answer.engine == .fallback)
    }

    @Test func firstAvailableEngineWins() async {
        let first = StubCoachEngine(kind: .claudeDemo, available: false, output: "Set 1 was fine.")
        let second = StubCoachEngine(kind: .privateCloudCompute, output: "Set 1 was fine.")
        let third = StubCoachEngine(kind: .onDevice, output: "Set 1 was fine.")
        let responder = CoachResponder(
            selector: CoachEngineSelector(engines: [first, second, third]),
            language: .english
        )
        #expect(responder.currentEngineKind == .privateCloudCompute)
        _ = await responder.answer("Hi", context: CoachContext.make(history: history()), history: [])
        #expect(first.calls == 0 && second.calls == 1 && third.calls == 0)
    }

    @Test func conversationKeepsTurnsAndPassesEarlierOnes() async {
        let engine = StubCoachEngine(output: "Set 2")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let conversation = CoachConversation(history: history(), responder: responder)
        #expect(conversation.messages.count == 1)
        #expect(conversation.suggestedQuestions.first == "How did my last set go?")
        await conversation.send("What about set 2?")
        #expect(conversation.messages.count == 3)
        #expect(conversation.messages[1].role == .person)
        #expect(conversation.messages[2].engine == .onDevice)
        #expect(engine.lastHistory?.count == 1)
        await conversation.send("   ")
        #expect(conversation.messages.count == 3)
    }

    @Test func promptsAndAnalysisMeetTheirFallbackIntentsInEveryLanguage() {
        for language in [CoachLanguage.english, .french, .spanish] {
            let responder = CoachResponder(selector: CoachEngineSelector(engines: []), language: language)
            let conversation = CoachConversation(history: history(), responder: responder)
            #expect(conversation.suggestedQuestions.map(CoachFallback.intent(of:)) == [
                .recap,
                .progress,
                .advice
            ])
            #expect(CoachFallback.intent(of: conversation.analysisRequest) == .advice)
        }
    }

    @Test func standardBuildNeverSelectsUnentitledCloudCompute() {
        #expect(CoachEngineSelector.standard().current()?.kind != .privateCloudCompute)
    }

    @Test func noSavedSetsStillChatsWithTheModel() async {
        let engine = StubCoachEngine(output: "Hi! Record your first set and I'll walk you through it.")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let answer = await responder.answer("Hello", context: CoachContext(facts: []), history: [])
        #expect(answer.engine == .onDevice)
        #expect(answer.text.hasPrefix("Hi! Record your first set"))
        #expect(engine.calls == 1)
    }

    /// The onboarding answers reach the model through the context, so tests and demo input use
    /// their own answers rather than the device's. They follow the rules, never replace them
    @Test func theInstructionsCarryTheOnboardingAnswersFromTheContext() {
        let context = CoachContext(facts: [], profile: "Past injuries, in their words: bad left knee")
        let prompt = FoundationModelsCoachPrompt.make(
            question: "How am I doing?", context: context, history: [], language: .english
        )
        #expect(prompt.instructions.hasPrefix(CoachInstructions.english))
        #expect(prompt.instructions.contains("About the person, from their onboarding answers:\nPast injuries, in their words: bad left knee"))
        #expect(prompt.instructions.hasSuffix("Saved sets: no saved sets yet."))
        #expect(prompt.question == "How am I doing?")

        let plain = FoundationModelsCoachPrompt.make(
            question: "How am I doing?", context: CoachContext(facts: []), history: [], language: .english
        )
        #expect(!plain.instructions.contains("About the person, from"))
    }

    /// every answered onboarding question, one a line; unanswered ones are left out
    @Test func theMemoryDocumentListsEveryOnboardingAnswer() throws {
        #expect(OnboardingProfile().coachMemory == nil)
        let profile = OnboardingProfile(
            goal: .muscle, level: .regular, favouriteExercises: [.pushUp], firstName: "  Léa ",
            followedProgram: true, stopReasons: [.injury], intensity: .challenge, days: .threeToFour,
            sex: .female, heightCentimeters: 168, weightKilograms: 61,
            location: .home, equipment: [.dumbbells, .pullUpBar], injuries: "Left knee\nsince 2023"
        )
        let memory = try #require(profile.coachMemory)
        let lines = memory.split(separator: "\n").map(String.init)
        #expect(lines.first == "First name: Léa")
        #expect(lines.contains("Goal: " + TrainingGoal.muscle.title))
        #expect(lines.contains("Training level: " + TrainingLevel.regular.title))
        #expect(lines.contains("Favourite exercises: " + ExerciseKind.pushUp.definition.copy.name))
        #expect(lines.contains("Has followed a training programme before: yes; stopped because: " + ProgramStopReason.injury.title))
        #expect(lines.contains("How hard Finn should push: " + TrainingIntensity.challenge.title))
        #expect(lines.contains("Days a week they can train: " + TrainingDays.threeToFour.title))
        #expect(lines.contains("Height: 168 cm"))
        #expect(lines.contains { $0.hasPrefix("Weight: 61") })
        #expect(lines.contains("Where they train: " + TrainingLocation.home.title))
        #expect(lines.contains("Equipment: " + [TrainingEquipment.dumbbells, .pullUpBar].map(\.title).joined(separator: ", ")))
        #expect(lines.last == "Past injuries, in their words: Left knee since 2023")
        #expect(lines.count == 13)

        let partial = OnboardingProfile(goal: .comeback, noPastInjuries: true)
        #expect(partial.coachMemory == "Goal: \(TrainingGoal.comeback.title)\nPast injuries: none")
    }

    /// Finn rereads the memory each turn, and the conversation as real turns: every recent
    /// message in full, the person's and Finn's alternating, without the app's fixed greeting
    @Test func everyTurnRereadsTheMemoryAndTheConversationAsTurns() async {
        let engine = StubCoachEngine(output: "Sure.")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let conversation = CoachConversation(history: history(), responder: responder, profile: "First name: Léa")
        let long = "I train at home with two dumbbells and I want to get stronger arms before summer. " +
            String(repeating: "More detail. ", count: 20) + "That's all."
        for turn in 1 ... 6 {
            await conversation.send("Turn \(turn). " + long)
        }
        let prompt = FoundationModelsCoachPrompt.make(
            question: "Remember me?", context: conversation.context, history: engine.lastHistory ?? [], language: .english
        )
        #expect(prompt.instructions.contains("First name: Léa"))
        #expect(prompt.instructions.contains("they have recorded sets with Finn"))
        #expect(!prompt.instructions.contains("Set 3: Push-up"))
        #expect(prompt.turns.map(\.role) == Array(repeating: [CoachMessage.Role.person, .coach], count: 5).flatMap { $0 })
        #expect(prompt.turns.map(\.text) == (1 ... 5).flatMap { ["Turn \($0). " + long, "Sure."] })
        #expect(!prompt.turns.contains { $0.text == conversation.messages.first?.text })
        #expect(prompt.question == "Remember me?")
    }

    /// the saved sets are listed for a question about training, or a follow-up to one; small talk
    /// only learns that sets exist, so the model does not offer them as workouts to do
    @Test func theSetsAreListedOnlyForQuestionsAboutTraining() {
        let context = CoachContext.make(history: history())
        func instructions(_ question: String, after previous: String? = nil) -> String {
            let history = previous.map { [CoachMessage(role: .person, text: $0),
                                          CoachMessage(role: .coach, text: "Reply", engine: .onDevice)] } ?? []
            return FoundationModelsCoachPrompt.make(question: question, context: context, history: history,
                                                    language: .english).instructions
        }
        for chat in ["Hey bro I can talk to you now", "Good", "ok", "What should I eat after?", "Salut coach !"] {
            #expect(!instructions(chat).contains("Set 3: Push-up"), "\(chat)")
            #expect(instructions(chat).contains("they have recorded sets with Finn"))
        }
        // the last session alone: the set before is left out, so it cannot be taken for the last
        let aboutTheLast = ["How did my last set go?", "What should I focus on next time?", "How many reps did I do?",
                            "Comment s'est passée ma dernière série ?", "Sur quoi me concentrer la prochaine fois ?",
                            "¿Cómo fue mi última serie?", "¿En qué debería enfocarme la próxima vez?"]
        for question in aboutTheLast {
            #expect(instructions(question).contains("Their most recent set is Set 3: Push-up"), "\(question)")
            #expect(!instructions(question).contains("Set 2: Squat"), "\(question)")
        }
        // a comparison or a numbered set: every set
        let comparing = ["What changed across my sets?", "Qu'est-ce qui a changé sur mes séries ?", "¿Qué cambió en mis series?",
                         "How was set 1?", "Et la série 2 ?", "Am I improving?"]
        for question in comparing {
            #expect(instructions(question).contains("Set 1: Squat"), "\(question)")
        }
        for language in [CoachLanguage.english, .french, .spanish] {
            let conversation = CoachConversation(history: history(), responder: CoachResponder(
                selector: CoachEngineSelector(engines: []), language: language))
            #expect(FoundationModelsCoachPrompt.setsNeeded(for: conversation.analysisRequest) == .all)
        }
        #expect(instructions("Why?", after: "How did my last set go?").contains("Set 3: Push-up"))
        #expect(FoundationModelsCoachPrompt.make(question: "Hi", context: CoachContext(facts: []), history: [],
                                                 language: .english).instructions.hasSuffix("Saved sets: no saved sets yet."))
    }

    /// turns alternate and start with the person, as a session expects; a question left without
    /// an answer is merged away, since the person asks again now
    @Test func turnsAlternateAndStartWithThePerson() {
        let prompt = FoundationModelsCoachPrompt.make(question: "Third?", context: CoachContext(facts: []), history: [
            CoachMessage(role: .coach, text: "Fixed greeting"),
            CoachMessage(role: .coach, text: "A reply before the window", engine: .onDevice),
            CoachMessage(role: .person, text: "First"),
            CoachMessage(role: .person, text: "and more"),
            CoachMessage(role: .coach, text: "Answer", engine: .fallback),
            CoachMessage(role: .person, text: "Unanswered"),
        ], language: .english)
        #expect(prompt.turns.map(\.role) == [.person, .coach])
        #expect(prompt.turns.map(\.text) == ["First\nand more", "Answer"])
        #expect(prompt.transcript.count == 3)
    }

    /// a conversation longer than the window drops its oldest messages, never the newest
    @Test func aLongConversationForgetsItsOldestMessagesFirst() {
        let turns = (1 ... 30).map {
            CoachMessage(role: $0.isMultiple(of: 2) ? .coach : .person, text: "Message \($0) " + String(repeating: "x", count: 300),
                         engine: $0.isMultiple(of: 2) ? .onDevice : nil)
        }
        let context = CoachContext(facts: [], profile: "Goal: Build muscle")
        let prompt = FoundationModelsCoachPrompt.make(
            question: "Still there?", context: context, history: turns, language: .english, maximumCharacters: 6_000
        )
        let size = prompt.instructions.count + prompt.turns.reduce(0) { $0 + $1.text.count } + prompt.question.count
        #expect(size <= 6_000)
        #expect(prompt.instructions.contains("Goal: Build muscle"))
        #expect(prompt.turns.last?.text.hasPrefix("Message 30 ") == true)
        #expect(prompt.turns.first?.role == .person)
        #expect(!prompt.turns.contains { $0.text.hasPrefix("Message 1 ") })
    }

    /// the on-device window holds the rules, the longest answers, sets and question, plus a full
    /// conversation of messages around 200 characters
    @Test func theOnDeviceWindowHoldsAFullConversation() {
        let budget = FoundationModelsCoachPrompt.characterBudget(contextSize: 8_192)
        // a long sitting: 40 messages
        let full = 40 * 200
        #expect(budget >= CoachInstructions.text(language: .french).count + FoundationModelsCoachPrompt.profileCharacters
            + FoundationModelsCoachPrompt.setCharacters + FoundationModelsCoachPrompt.maximumQuestionCharacters + full)
        #expect(FoundationModelsCoachPrompt.characterBudget(contextSize: 0) == 0)
    }

    /// the conversation is still there when the app reopens, under a fresh greeting
    @Test func theConversationComesBackAfterARelaunch() async throws {
        let defaults = try #require(UserDefaults(suiteName: "CoachTranscript-\(UUID().uuidString)"))
        let engine = StubCoachEngine(output: "Sure, Léa.")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let first = CoachConversation(history: [], responder: responder, transcript: CoachTranscriptStore(defaults: defaults))
        await first.send("Can we talk?")
        await first.send("What should I train today?")

        let reopened = CoachConversation(
            history: history(), responder: responder, transcript: CoachTranscriptStore(defaults: defaults)
        )
        #expect(reopened.messages.count == 5)
        #expect(reopened.messages.first?.text == CoachFallback.opening(context: reopened.context, language: .english))
        #expect(Array(reopened.messages.dropFirst()) == Array(first.messages.dropFirst()))
        #expect(reopened.messages.last?.engine == .onDevice)

        // the next turn rereads the restored messages too
        await reopened.send("And tomorrow?")
        #expect(engine.lastHistory?.map(\.text).contains("What should I train today?") == true)
    }

    @Test func theSavedConversationKeepsOnlyTheLatestTurns() throws {
        let defaults = try #require(UserDefaults(suiteName: "CoachTranscript-\(UUID().uuidString)"))
        let store = CoachTranscriptStore(defaults: defaults)
        let count = CoachTranscriptStore.maximumTurns + 21
        let turns = (1 ... count).map { CoachMessage(role: $0.isMultiple(of: 2) ? .coach : .person, text: "Message \($0)") }
        store.save(turns + [CoachMessage(role: .person, text: "")])
        #expect(store.turns.count == CoachTranscriptStore.maximumTurns)
        #expect(store.turns.first?.text == "Message 22")
        #expect(store.turns.last?.text == "Message \(count)")
        #expect(CoachTranscriptStore(defaults: defaults).turns == store.turns)
    }

    /// Delete all data empties the saved conversation; the screen starts over and drops a reply
    /// that was on its way
    @Test func forgettingStartsOverAndDropsAReplyOnItsWay() async throws {
        let defaults = try #require(UserDefaults(suiteName: "CoachTranscript-\(UUID().uuidString)"))
        let store = CoachTranscriptStore(defaults: defaults)
        let engine = StubCoachEngine(output: "Late reply", delay: .milliseconds(100))
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let conversation = CoachConversation(history: [], responder: responder, transcript: store)
        let request = Task { await conversation.send("Hello?") }
        while !conversation.isAnswering {
            await Task.yield()
        }
        store.clear()
        conversation.forget()
        await request.value
        #expect(conversation.messages.count == 1)
        #expect(store.turns.isEmpty)
        #expect(CoachTranscriptStore(defaults: defaults).turns.isEmpty)
    }

    /// like a messaging app: the day above the first message of each day, a thin line when they
    /// come back an hour or more later the same day, nothing between messages minutes apart
    @Test func theThreadMarksDaysAndPauses() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9, minute: 0))!
        func message(_ minutes: Double) -> CoachMessage {
            CoachMessage(role: .person, text: "Hi", sentAt: morning.addingTimeInterval(minutes * 60))
        }
        #expect(CoachTimeline.marker(for: message(0), after: nil, calendar: calendar) == .day(morning))
        #expect(CoachTimeline.marker(for: message(3), after: message(0), calendar: calendar) == nil)
        #expect(CoachTimeline.marker(for: message(59), after: message(0), calendar: calendar) == nil)
        #expect(CoachTimeline.marker(for: message(60), after: message(0), calendar: calendar) == .pause)
        #expect(CoachTimeline.marker(for: message(150), after: message(10), calendar: calendar) == .pause)
        // past midnight is a new day, even minutes later
        let late = CoachMessage(role: .person, text: "Hi", sentAt: morning.addingTimeInterval(14 * 3_600 + 58 * 60))
        let nextDay = CoachMessage(role: .coach, text: "Hi", engine: .onDevice, sentAt: late.sentAt.addingTimeInterval(4 * 60))
        #expect(CoachTimeline.marker(for: nextDay, after: late, calendar: calendar) == .day(nextDay.sentAt))
    }

    /// Today and Yesterday, then the weekday within the week, then the date, in the person's language
    @Test func theDayReadsLikeAMessagingApp() {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        let english = Locale(identifier: "en_US")
        let french = Locale(identifier: "fr_FR")
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now)!
        }
        #expect(CoachTimeline.dayLabel(for: now, now: now, calendar: calendar, locale: english) == "Today")
        #expect(CoachTimeline.dayLabel(for: daysAgo(1), now: now, calendar: calendar, locale: english) == "Yesterday")
        #expect(CoachTimeline.dayLabel(for: now, now: now, calendar: calendar, locale: french).hasPrefix("Aujourd"))
        #expect(CoachTimeline.dayLabel(for: daysAgo(1), now: now, calendar: calendar, locale: french) == "Hier")
        let weekday = daysAgo(3).formatted(Date.FormatStyle(locale: french, calendar: calendar).weekday(.wide))
        #expect(CoachTimeline.dayLabel(for: daysAgo(3), now: now, calendar: calendar, locale: french)
            == weekday.prefix(1).uppercased() + weekday.dropFirst())
        let older = CoachTimeline.dayLabel(for: daysAgo(400), now: now, calendar: calendar, locale: english)
        #expect(older.contains(String(calendar.component(.year, from: daysAgo(400)))))
        // a 24-hour clock in French, like 14:27; AM and PM in American English
        let afternoon = calendar.date(bySettingHour: 14, minute: 27, second: 0, of: now)!
        #expect(CoachTimeline.time(of: afternoon, locale: french) == "14:27")
        #expect(CoachTimeline.time(of: afternoon, locale: english).hasSuffix("PM"))
    }

    /// messages saved before they carried a time still load
    @Test func messagesSavedWithoutATimeStillLoad() throws {
        let saved = #"[{"id":"\#(UUID().uuidString)","role":"person","text":"Old question"}]"#
        let messages = try JSONDecoder().decode([CoachMessage].self, from: Data(saved.utf8))
        #expect(messages.first?.text == "Old question")
        #expect(abs(messages.first?.sentAt.timeIntervalSinceNow ?? 100) < 5)
        let sent = CoachMessage(role: .coach, text: "Reply", engine: .onDevice, sentAt: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(try JSONDecoder().decode(CoachMessage.self, from: JSONEncoder().encode(sent)) == sent)
    }

    /// the greeting heads the screen, so a long conversation keeps it and drops the oldest turns
    @Test func aLongConversationKeepsTheGreeting() async {
        let engine = StubCoachEngine(output: "OK.")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let conversation = CoachConversation(history: [], responder: responder)
        let greeting = conversation.messages.first
        for turn in 1 ... CoachConversation.maximumMessages / 2 + 5 {
            await conversation.send("Question \(turn)")
        }
        #expect(conversation.messages.count == CoachConversation.maximumMessages)
        #expect(conversation.messages.first == greeting)
        // ten messages too many, plus the greeting's place: the answer to question 6, then question 7 on
        #expect(conversation.messages[2].text == "Question 7")
        #expect(conversation.messages.last?.text == "OK.")
    }

    @Test func promptSizeStaysBoundedForLongQuestionsAndHistory() {
        let huge = String(repeating: "more context ", count: 10_000)
        let turns = (0 ..< 20).map { _ in CoachMessage(role: .person, text: huge) }
        let prompt = FoundationModelsCoachPrompt.make(
            question: huge, context: CoachContext.make(history: history()), history: turns, language: .english
        )
        let size = prompt.instructions.count + prompt.turns.reduce(0) { $0 + $1.text.count } + prompt.question.count
        #expect(size <= FoundationModelsCoachPrompt.maximumPromptCharacters)
        #expect(prompt.question.count == FoundationModelsCoachPrompt.maximumQuestionCharacters)
    }

    @Test func negativeContextLimitDoesNotTrap() {
        #expect(CoachContext.make(history: history(), limit: -1).isEmpty)
    }

    @Test func promptBudgetKeepsTheLatestSetsWhenOldObservationsAreLong() {
        let facts = (1 ... 32).map { number in
            CoachSetFact(
                number: number,
                id: UUID(),
                exerciseName: "Squat",
                repCount: number,
                capturedAt: .now,
                observation: String(repeating: "Recorded fact. ", count: 1_000),
                issues: [],
                comparison: nil,
                partlyVisible: false
            )
        }
        let prompt = CoachContext(facts: facts).memoryText(maximumCharacters: 4_000)
        #expect(prompt.count <= 4_000)
        #expect(prompt.hasPrefix("Their most recent set is Set 32: Squat, 32 reps"))
        #expect(prompt.contains("they mean this one.\nSets they did before it, newest first:\nSet 31: Squat, 31 reps"))
        #expect(!prompt.contains("Set 1:"))
        // a French app names them in French, so the reply does too
        #expect(CoachContext(facts: facts).memoryText(maximumCharacters: 4_000, setWord: "Série")
            .hasPrefix("Their most recent set is Série 32: Squat"))
    }

    @Test func refreshingDeletedHistoryAnswersWithoutUsingRemovedSets() async {
        let engine = StubCoachEngine(output: "Set 1", delay: .milliseconds(100))
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let conversation = CoachConversation(history: history(), responder: responder)
        let request = Task { await conversation.send("How was set 1?") }
        while !conversation.isAnswering {
            await Task.yield()
        }
        conversation.refresh(history: [], profile: nil)
        await request.value
        #expect(conversation.messages.count == 3)
        #expect(conversation.messages.last?.engine == .fallback)
        #expect(conversation.messages.last?.text.contains("Workout tab") == true)
        #expect(conversation.messages.last?.text.contains("6 squat reps") == false)
        #expect(!conversation.isAnswering)
    }

    @Test func newSavedSetsRefreshTheGreetingWithoutPretendingToRunAModel() {
        let responder = CoachResponder(selector: CoachEngineSelector(engines: []), language: .english)
        let conversation = CoachConversation(history: [], responder: responder)
        let greetingID = conversation.messages.first?.id
        conversation.refresh(history: history(), profile: nil)
        #expect(conversation.messages.first?.text == CoachFallback.opening(
            context: conversation.context,
            language: .english
        ))
        #expect(conversation.messages.first?.id == greetingID)
        #expect(conversation.messages.first?.engine == nil)
    }

    @Test func leavingCoachCancelsTheTurnWithoutAppendingAnAnswer() async {
        let engine = StubCoachEngine(output: "Set 1", delay: .seconds(5))
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let conversation = CoachConversation(history: history(), responder: responder)
        let request = Task { await conversation.send("How was set 1?") }
        while !conversation.isAnswering {
            await Task.yield()
        }
        request.cancel()
        await request.value
        #expect(conversation.messages.count == 2)
        #expect(!conversation.isAnswering)
    }

    @Test func aTimedOutUncooperativeModelCannotStartOverlappingInference() async {
        let engine = SuspendedCoachEngine()
        let responder = CoachResponder(
            selector: CoachEngineSelector(engines: [engine]),
            timeout: .milliseconds(30),
            language: .english
        )
        let context = CoachContext.make(history: history())
        let first = await responder.answer("First", context: context, history: [])
        #expect(first.engine == .fallback)
        let second = await responder.answer("Second", context: context, history: [])
        #expect(second.engine == .fallback)
        #expect(engine.calls == 1)
        engine.finish()
        await Task.yield()
    }

    // MARK: Validator and prompt

    @Test func answerCheckReadsSetReferencesInBothLanguages() {
        #expect(CoachAnswerCheck.referencedSetNumbers(in: "Set 2 and set #3, then Série 4 and série 5.") == [
            2,
            3,
            4,
            5
        ])
        #expect(CoachAnswerCheck.referencedSetNumbers(in: "A set of 8 reps.") == [])
        let context = CoachContext.make(history: history())
        #expect(CoachAnswerCheck.selectedFacts(in: "Set 2, Série 3", for: context)?.map(\.number) == [2, 3])
        #expect(CoachAnswerCheck.selectedFacts(in: "Set 2 had perfect posture", for: context) == nil)
        #expect(CoachAnswerCheck.selectedFacts(in: "Set 2, Set 2", for: context) == nil)
        #expect(CoachAnswerCheck.selectedFacts(in: "Set 7", for: context) == nil)
    }

    @Test func instructionsCarryTheRulesAndTheLanguage() {
        let context = CoachContext.make(history: history())
        let english = FoundationModelsCoachPrompt.instructions(language: .english)
        #expect(english.contains("No medical advice"))
        #expect(english.contains("Reply to anything they write"))
        #expect(english.contains("Always reply in the language of the person's latest message."))
        #expect(english.contains("never start a reply with a greeting or with their name"))
        #expect(english.contains("Never repeat a sentence, a suggestion or a question"))
        #expect(!english.contains("Set 3: Push-up"))
        let french = FoundationModelsCoachPrompt.instructions(language: .french)
        #expect(french.contains("reply in French and address the person as \"tu\""))
        let spanish = FoundationModelsCoachPrompt.instructions(language: .spanish)
        #expect(spanish.contains("reply in Spanish and address the person as \"tú\""))
        let prompt = FoundationModelsCoachPrompt.make(question: "Et ma dernière série ?", context: context, history: [
            CoachMessage(role: .person, text: "Earlier question"),
            CoachMessage(role: .coach, text: "Earlier answer", engine: .onDevice),
        ], language: .french)
        #expect(prompt.instructions.contains("Their most recent set is Série 3: Push-up"))
        #expect(prompt.turns.map(\.text) == ["Earlier question", "Earlier answer"])
        #expect(prompt.question == "Et ma dernière série ?")
    }

    #if DEBUG
        @Test func claudeDemoBodyUsesSonnetWithTheSameInstructions() throws {
            let context = CoachContext.make(history: history())
            let body = ClaudeDemoCoachEngine.body(question: "How did set 3 go?", context: context, history: [
                CoachMessage(role: .coach, text: "Opening line", engine: .claudeDemo),
                CoachMessage(role: .person, text: "First question"),
                CoachMessage(role: .coach, text: "Set 1 was fine.", engine: .claudeDemo),
            ], language: .english)
            #expect(body["model"] as? String == "claude-sonnet-5-5")
            #expect((body["system"] as? String)?.hasPrefix(CoachInstructions.english) == true)
            #expect((body["system"] as? String)?.contains("Their most recent set is Set 3: Push-up") == true)
            let messages = body["messages"] as? [[String: String]]
            #expect(messages?.map { $0["role"] } == ["user", "assistant", "user"])
            #expect(messages?.last?["content"] == "How did set 3 go?")
            let data = try JSONSerialization.data(withJSONObject: ["content": [[
                "type": "text",
                "text": "Set 3: 8 push-ups."
            ]]])
            #expect(try ClaudeDemoCoachEngine.text(from: data) == "Set 3: 8 push-ups.")
        }
    #endif
}

@MainActor
private final class StubCoachEngine: CoachEngine {
    let kind: CoachEngineKind
    let available: Bool
    private let output: String?
    private let error: (any Error)?
    private let delay: Duration?
    private(set) var calls = 0
    private(set) var lastHistory: [CoachMessage]?
    private(set) var lastInstructionsContext: CoachContext?

    struct Failure: Error {}

    init(
        kind: CoachEngineKind = .onDevice,
        available: Bool = true,
        output: String?,
        error: (any Error)? = nil,
        delay: Duration? = nil
    ) {
        self.kind = kind
        self.available = available
        self.output = output
        self.error = error
        self.delay = delay
    }

    func reply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage
    ) async throws -> String {
        calls += 1
        lastHistory = history
        lastInstructionsContext = context
        if let delay {
            try await Task.sleep(for: delay)
        }
        guard let output else {
            throw error ?? Failure()
        }
        return output
    }
}

/// writes its reply in parts, like the on-device model's stream
@MainActor
private final class StreamingCoachEngine: CoachEngine {
    let kind = CoachEngineKind.onDevice
    let available = true
    private let parts: [String]
    private let hangsAfterParts: Bool
    /// runs after each part reaches the responder
    var onEachPart: () -> Void = {}

    init(parts: [String], hangsAfterParts: Bool = false) {
        self.parts = parts
        self.hangsAfterParts = hangsAfterParts
    }

    func reply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage
    ) async throws -> String {
        parts.last ?? ""
    }

    func streamReply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        for part in parts {
            await Task.yield()
            onPartial(part)
            onEachPart()
        }
        if hangsAfterParts {
            try await Task.sleep(for: .seconds(5))
        }
        return parts.last ?? ""
    }
}

/// Simulates a framework operation that ignores task cancellation until it finishes.
@MainActor
private final class SuspendedCoachEngine: CoachEngine {
    let kind = CoachEngineKind.onDevice
    let available = true
    private(set) var calls = 0
    private var continuation: CheckedContinuation<String, Never>?

    func reply(
        to question: String,
        context: CoachContext,
        history: [CoachMessage],
        language: CoachLanguage
    ) async throws -> String {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }

    func finish() {
        continuation?.resume(returning: "Set 1")
        continuation = nil
    }
}
