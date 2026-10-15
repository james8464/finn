import Foundation
import Testing
@testable import Plumb

@MainActor
struct CoachTests {
    // MARK: Fixtures

    private func rep(_ number: Int, range: Double = 0.4) -> RepMetric {
        RepMetric(number: number, startTime: Double(number) * 2, endTime: Double(number) * 2 + 1.5, relativeRange: range)
    }

    private func set(session: UUID, at date: Date, exercise: ExerciseKind = .bodyweightSquat,
                     reps: Int = 6, range: Double = 0.4, cue: Cue? = nil,
                     issues: [SetIssue]? = nil, partlyVisible: Bool? = nil,
                     formMeasurements: [FormMeasurement]? = nil) -> SetSummary {
        SetSummary(id: UUID(), sessionID: session, capturedAt: date, bodySide: .left,
                   analysis: SetAnalysis(reps: (1...reps).map { rep($0, range: range) },
                                         confidence: 0.95, rubricVersion: "squat-side-v7"),
                   cue: cue, cueResponse: .unanswered, exercise: exercise, cameraView: .side,
                   issues: issues, formMeasurements: formMeasurements, partlyVisible: partlyVisible)
    }

    private var rangeCue: Cue {
        Cue(kind: .rangeDecreased, repNumbers: [5, 6], earlierMedian: 0.4, laterMedian: 0.3,
            observation: "Your last two reps were shallower than your first two.",
            nextAction: "Try reaching the same depth on every rep.")
    }

    private func history() -> [WorkoutSessionSummary] {
        let session = UUID()
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let first = set(session: session, at: start, range: 0.4, issues: [])
        let second = set(session: session, at: start.addingTimeInterval(300), range: 0.3,
                         cue: rangeCue, issues: [.rangeDropped])
        let later = UUID()
        let third = set(session: later, at: start.addingTimeInterval(90_000), exercise: .pushUp,
                        reps: 8, issues: [.partlyVisible], partlyVisible: true)
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
        #expect(context.facts[1].observation == "Your last two reps were shallower than your first two. Try reaching the same depth on every rep.")
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

    @Test func contextKeepsOnlyTheMostRecentSets() {
        let session = UUID()
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let sets = (0..<12).map { set(session: session, at: start.addingTimeInterval(Double($0) * 200), reps: $0 + 1) }
        let context = CoachContext.make(history: [WorkoutSessionSummary(id: session, startedAt: start, sets: sets)], limit: 5)
        #expect(context.facts.count == 5)
        #expect(context.facts.map(\.repCount) == [8, 9, 10, 11, 12])
        #expect(context.facts.first?.number == 1)
    }

    @Test func coachCanReportMeasuredFormChangeAcrossSessions() {
        let firstID = UUID()
        let secondID = UUID()
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let first = set(session: firstID, at: date,
                        formMeasurements: [FormMeasurement(check: .squatDepth, judged: 6,
                                                           faulty: 5, typical: 40)])
        let second = set(session: secondID, at: date.addingTimeInterval(90_000),
                         formMeasurements: [FormMeasurement(check: .squatDepth, judged: 6,
                                                            faulty: 1, typical: 20)])
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
        let first = set(session: session, at: date,
                        formMeasurements: [FormMeasurement(check: .squatDepth, judged: 6,
                                                           faulty: 5, typical: 40)])
        let obscured = set(session: session, at: date.addingTimeInterval(100),
                           partlyVisible: true,
                           formMeasurements: [FormMeasurement(check: .squatDepth, judged: 6,
                                                              faulty: 5, typical: 40)])
        let last = set(session: session, at: date.addingTimeInterval(200),
                       formMeasurements: [FormMeasurement(check: .squatDepth, judged: 6,
                                                          faulty: 1, typical: 20)])
        let context = CoachContext.make(history: [WorkoutSessionSummary(id: session, startedAt: date,
                                                                        sets: [first, obscured, last])])
        #expect(context.facts.last?.comparison?.contains("down from 5 of 6") == true)
    }

    @Test func coachKeepsLatestPriorForEachFormCheck() {
        let session = UUID()
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let depth = set(session: session, at: date,
                        formMeasurements: [FormMeasurement(check: .squatDepth, judged: 6,
                                                           faulty: 5, typical: 40)])
        let chest = set(session: session, at: date.addingTimeInterval(100),
                        formMeasurements: [FormMeasurement(check: .squatChestDrop, judged: 6,
                                                           faulty: 5, typical: 50)])
        let latest = set(session: session, at: date.addingTimeInterval(200),
                         formMeasurements: [FormMeasurement(check: .squatDepth, judged: 6,
                                                            faulty: 1, typical: 20),
                                            FormMeasurement(check: .squatChestDrop, judged: 6,
                                                            faulty: 1, typical: 20)])
        let context = CoachContext.make(history: [WorkoutSessionSummary(id: session, startedAt: date,
                                                                        sets: [depth, chest, latest])])
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
        #expect(answer.text.contains("no saved set"))
        let conversation = CoachConversation(history: [], responder: responder)
        #expect(conversation.messages.first?.text.contains("No saved set yet") == true)
        #expect(conversation.suggestedQuestions.isEmpty)
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
        let answer = await responder.answer("Alors ?", context: CoachContext.make(history: history()), history: [])
        #expect(answer.text.contains("Série 3 : 8 répétitions, push-up."))
    }

    // MARK: Simulated engine

    @Test func modelSelectionRendersOnlyRecordedSetFacts() async {
        let engine = StubCoachEngine(output: "Set 2, Set 3")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let context = CoachContext.make(history: history())
        let answer = await responder.answer("What happened?", context: context, history: [])
        #expect(answer.engine == .onDevice)
        #expect(answer.text.contains("Set 2: 6 squat reps. Observation: Your last two reps were shallower"))
        #expect(answer.text.contains("Set 3: 8 push-up reps."))
        #expect(engine.calls == 1)
        #expect(engine.lastInstructionsContext?.facts.count == 3)
    }

    @Test func answerCitingAnUnknownSetFallsBack() async {
        let engine = StubCoachEngine(output: "Set 7")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let answer = await responder.answer("Which was best?", context: CoachContext.make(history: history()), history: [])
        #expect(answer.engine == .fallback)
        #expect(!answer.text.contains("Set 7"))
    }

    @Test func generatedUnsupportedPostureClaimIsNeverShown() async {
        let engine = StubCoachEngine(output: "Set 2 had perfect posture and prevents knee injury.")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let answer = await responder.answer("How was set 2?", context: CoachContext.make(history: history()), history: [])
        #expect(answer.engine == .fallback)
        #expect(!answer.text.contains("perfect posture"))
        #expect(!answer.text.contains("prevents knee injury"))
    }

    @Test func emptyOrFailingAnswerFallsBack() async {
        let empty = StubCoachEngine(output: "   ")
        let context = CoachContext.make(history: history())
        let first = await CoachResponder(selector: CoachEngineSelector(engines: [empty]), language: .english)
            .answer("Hi", context: context, history: [])
        #expect(first.engine == .fallback)
        let failing = StubCoachEngine(output: nil)
        let second = await CoachResponder(selector: CoachEngineSelector(engines: [failing]), language: .english)
            .answer("Hi", context: context, history: [])
        #expect(second.engine == .fallback)
    }

    @Test func slowEngineFallsBackAfterTimeout() async {
        let engine = StubCoachEngine(output: "Set 1 was fine.", delay: .seconds(5))
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]),
                                       timeout: .milliseconds(100), language: .english)
        let answer = await responder.answer("Hi", context: CoachContext.make(history: history()), history: [])
        #expect(answer.engine == .fallback)
    }

    @Test func firstAvailableEngineWins() async {
        let first = StubCoachEngine(kind: .claudeDemo, available: false, output: "Set 1 was fine.")
        let second = StubCoachEngine(kind: .privateCloudCompute, output: "Set 1 was fine.")
        let third = StubCoachEngine(kind: .onDevice, output: "Set 1 was fine.")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [first, second, third]), language: .english)
        #expect(responder.currentEngineKind == .privateCloudCompute)
        _ = await responder.answer("Hi", context: CoachContext.make(history: history()), history: [])
        #expect(first.calls == 0 && second.calls == 1 && third.calls == 0)
    }

    @Test func conversationKeepsTurnsAndPassesEarlierOnes() async {
        let engine = StubCoachEngine(output: "Set 2")
        let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]), language: .english)
        let conversation = CoachConversation(history: history(), responder: responder)
        #expect(conversation.messages.count == 1)
        #expect(conversation.suggestedQuestions.first == "How did set 3 go?")
        await conversation.send("What about set 2?")
        #expect(conversation.messages.count == 3)
        #expect(conversation.messages[1].role == .person)
        #expect(conversation.messages[2].engine == .onDevice)
        #expect(engine.lastHistory?.count == 1)
        await conversation.send("   ")
        #expect(conversation.messages.count == 3)
    }

    // MARK: Validator and prompt

    @Test func answerCheckReadsSetReferencesInBothLanguages() {
        #expect(CoachAnswerCheck.referencedSetNumbers(in: "Set 2 and set #3, then Série 4 and série 5.") == [2, 3, 4, 5])
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
        #expect(!english.contains("Saved sets, oldest first:"))
        #expect(!english.contains("Set 3: Push-up"))
        let french = FoundationModelsCoachPrompt.instructions(language: .french)
        #expect(french.contains("For a French question, use \"Série N\""))
        let prompt = FoundationModelsCoachPrompt.prompt(question: "Now?", context: context, history: [
            CoachMessage(role: .person, text: "Earlier question"),
            CoachMessage(role: .coach, text: "Earlier answer", engine: .onDevice),
        ])
        #expect(prompt.contains("Saved sets, oldest first:"))
        #expect(prompt.contains("Set 3: Push-up"))
        #expect(prompt.contains("Person: Earlier question"))
        #expect(prompt.hasSuffix("Person now asks: Now?"))
    }

    @Test func structuredModelSelectionRejectsUnknownAndDuplicateSets() {
        let context = CoachContext.make(history: history())
        #expect(FoundationModelsCoachPrompt.labels(for: [2, 3], context: context) == "Set 2, Set 3")
        #expect(FoundationModelsCoachPrompt.labels(for: [9], context: context) == nil)
        #expect(FoundationModelsCoachPrompt.labels(for: [2, 2], context: context) == nil)
        #expect(FoundationModelsCoachPrompt.labels(for: [1, 2, 3], context: context) == nil)
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
        #expect((body["system"] as? String)?.contains("Set 3: Push-up") == false)
        let messages = body["messages"] as? [[String: String]]
        #expect(messages?.map { $0["role"] } == ["user", "assistant", "user"])
        #expect(messages?.last?["content"]?.contains("Set 3: Push-up") == true)
        #expect(messages?.last?["content"]?.hasSuffix("Person now asks: How did set 3 go?") == true)
        let data = try JSONSerialization.data(withJSONObject: ["content": [["type": "text", "text": "Set 3: 8 push-ups."]]])
        #expect(try ClaudeDemoCoachEngine.text(from: data) == "Set 3: 8 push-ups.")
    }
    #endif
}

@MainActor
private final class StubCoachEngine: CoachEngine {
    let kind: CoachEngineKind
    let available: Bool
    private let output: String?
    private let delay: Duration?
    private(set) var calls = 0
    private(set) var lastHistory: [CoachMessage]?
    private(set) var lastInstructionsContext: CoachContext?

    struct Failure: Error {}

    init(kind: CoachEngineKind = .onDevice, available: Bool = true, output: String?, delay: Duration? = nil) {
        self.kind = kind
        self.available = available
        self.output = output
        self.delay = delay
    }

    func reply(to question: String, context: CoachContext, history: [CoachMessage],
               language: CoachLanguage) async throws -> String {
        calls += 1
        lastHistory = history
        lastInstructionsContext = context
        if let delay { try await Task.sleep(for: delay) }
        guard let output else { throw Failure() }
        return output
    }
}
