import Foundation
import Testing
@testable import Finn

@MainActor
struct LivePersonalisedCoachTests {
    private let definition = ExerciseKind.bodyweightSquat.definition
    private var reps: [RepMetric] {
        (1...5).map {
            RepMetric(number: $0, startTime: Double($0) * 2,
                      endTime: Double($0) * 2 + 2, relativeRange: 0.3)
        }
    }

    @Test func historyCannotCreateAnUnmeasuredFault() {
        let context = LiveCoachContext(priorAcceptedChecks: [.squatDepth])
        let choices = LiveCoachChoices.make(event: .repCounted(5), reps: reps,
                                           definition: definition, canCompareRange: false,
                                           context: context, language: .english)
        #expect(!choices.contains { $0.id.hasPrefix("history:") })
        #expect(!choices.contains { $0.text.contains("steady") })
    }

    @Test func repeatingMeasuredTechniqueCanReferenceEarlierAcceptedEvidence() {
        let context = LiveCoachContext(priorAcceptedChecks: [.squatDepth])
        let choices = LiveCoachChoices.make(event: .formFault(.squatDepth, rep: 5), reps: reps,
                                           definition: definition, canCompareRange: true,
                                           context: context, language: .english)
        #expect(choices.contains { $0.id == "history:squatDepth" })
        #expect(choices.allSatisfy { !$0.text.isEmpty })
        let unrelated = LiveCoachChoices.make(event: .formFault(.squatChestDrop, rep: 5), reps: reps,
                                             definition: definition, canCompareRange: true,
                                             context: context, language: .english)
        #expect(!unrelated.contains { $0.id.hasPrefix("history:") })
    }

    @Test func malformedEventsAndSelectionsAreRejected() {
        let invalid = LiveCoachChoices.make(event: .formFault(.pushUpDepth, rep: 5), reps: reps,
                                           definition: definition, canCompareRange: true,
                                           context: .init(), language: .english)
        #expect(invalid.isEmpty)
        let choices = [LiveCoachChoice(id: "one", text: "Measured cue")]
        #expect(LiveCoachChoices.selected(-1, from: choices) == nil)
        #expect(LiveCoachChoices.selected(1, from: choices) == nil)
        #expect(LiveCoachChoices.selected(nil, from: choices) == nil)
        #expect(LiveCoachChoices.selected(0, from: choices)?.text == "Measured cue")
    }

    @Test func preparingSkipsUnavailableModelsAndForwardsResolvedLanguage() {
        let unavailable = StubLiveCoachSelector(available: false)
        LivePersonalisedCoach(selector: unavailable).prepare(language: .french)
        #expect(unavailable.preparedLanguages.isEmpty)
        let available = StubLiveCoachSelector(available: true)
        let coach = LivePersonalisedCoach(selector: available)
        coach.prepare(language: .spanish)
        #expect(available.preparedLanguages == [.spanish])
        coach.reset()
        #expect(available.resetCount == 1)
    }

    @Test func unavailableModelStillGivesImmediateAdviceAndVariesIt() {
        let engine = StubLiveCoachSelector(available: false)
        let coach = LivePersonalisedCoach(selector: engine)
        var lines: [String] = []
        for _ in 0..<2 {
            coach.update(event: .formFault(.squatDepth, rep: 5), reps: reps, definition: definition,
                         canCompareRange: true, context: .init(), language: .english) { lines.append($0) }
        }
        #expect(lines.count == 2)
        #expect(lines[0] != lines[1])
        #expect(lines[1] == FormCheck.squatDepth.liveCue)
        #expect(engine.calls == 0)
        coach.reset()
    }

    @Test func newerEventDiscardsDelayedModelAnswer() async {
        let engine = StubLiveCoachSelector(available: true)
        let coach = LivePersonalisedCoach(selector: engine)
        var lines: [String] = []
        coach.update(event: .formFault(.squatDepth, rep: 5), reps: reps, definition: definition,
                     canCompareRange: true, context: .init(), language: .english) { lines.append($0) }
        await waitForRequest(engine)
        coach.update(event: .repCountRevised(4), reps: Array(reps.prefix(4)), definition: definition,
                     canCompareRange: true, context: .init(), language: .english) { lines.append($0) }
        engine.finish(index: 1)
        for _ in 0..<20 { await Task.yield() }
        #expect(lines.count == 1)
        coach.reset()
    }

    @Test func endingCaptureDiscardsDelayedModelAnswer() async {
        let engine = StubLiveCoachSelector(available: true)
        let coach = LivePersonalisedCoach(selector: engine)
        var lines: [String] = []
        coach.update(event: .formFault(.squatDepth, rep: 5), reps: reps, definition: definition,
                     canCompareRange: true, context: .init(), language: .english) { lines.append($0) }
        await waitForRequest(engine)
        coach.reset()
        engine.finish(index: 1)
        for _ in 0..<20 { await Task.yield() }
        #expect(lines.count == 1)
    }

    @Test func modelThrottleNeverThrottlesTheLocalTechniqueCue() async {
        let engine = StubLiveCoachSelector(available: true)
        let coach = LivePersonalisedCoach(selector: engine, now: { 10 })
        var lines: [String] = []
        coach.update(event: .formFault(.squatDepth, rep: 5), reps: reps, definition: definition,
                     canCompareRange: true, context: .init(), language: .english) { lines.append($0) }
        await waitForRequest(engine)
        engine.finish(index: 0)
        for _ in 0..<20 { await Task.yield() }
        coach.update(event: .formFault(.squatChestDrop, rep: 5), reps: reps, definition: definition,
                     canCompareRange: true, context: .init(), language: .english) { lines.append($0) }
        for _ in 0..<20 { await Task.yield() }
        #expect(engine.calls == 1)
        #expect(lines.count == 2)
        coach.reset()
    }

    @Test func historyExcludesRejectedAndUnreadableEvidenceAndBoundsRecentSessions() {
        func session(response: CueResponse = .unanswered, partlyVisible: Bool = false,
                     check: FormCheck = .squatDepth) -> WorkoutSessionSummary {
            let id = UUID()
            let set = SetSummary(id: UUID(), sessionID: id, capturedAt: .now, bodySide: .left,
                                 analysis: SetAnalysis(reps: reps, confidence: 0.9,
                                                       rubricVersion: "squat-side-v7"),
                                 cue: nil, cueResponse: response, exercise: .bodyweightSquat,
                                 formMeasurements: [FormMeasurement(check: check, judged: 5,
                                                                    faulty: 3, typical: 35)],
                                 partlyVisible: partlyVisible)
            return WorkoutSessionSummary(id: id, startedAt: .now, sets: [set])
        }
        #expect(LiveCoachContext.acceptedChecks(in: [session()], exercise: .bodyweightSquat)
                == [.squatDepth])
        #expect(LiveCoachContext.acceptedChecks(in: [session(response: .notRelevant)],
                                                exercise: .bodyweightSquat).isEmpty)
        #expect(LiveCoachContext.acceptedChecks(in: [session(partlyVisible: true)],
                                                exercise: .bodyweightSquat).isEmpty)
        let recent = (0..<32).map { _ in session(response: .notRelevant) }
        let history = recent + [session(check: .squatChestDrop)]
        #expect(LiveCoachContext.acceptedChecks(in: history, exercise: .bodyweightSquat).isEmpty)
    }

    @Test func historicalMessageUsesTheResolvedLanguage() {
        for language in [CoachLanguage.french, .spanish] {
            let choices = LiveCoachChoices.make(event: .formFault(.squatDepth, rep: 5), reps: reps,
                                               definition: definition, canCompareRange: true,
                                               context: .init(priorAcceptedChecks: [.squatDepth]),
                                               language: language)
            let history = choices.first { $0.id.hasPrefix("history:") }
            #expect(history != nil)
            #expect(history?.text.contains("earlier sets") == false)
        }
    }

    private func waitForRequest(_ engine: StubLiveCoachSelector) async {
        for _ in 0..<100 {
            if engine.calls > 0 { return }
            await Task.yield()
        }
        #expect(engine.calls > 0)
    }
}

@MainActor
private final class StubLiveCoachSelector: LiveCoachSelecting {
    let available: Bool
    private(set) var calls = 0
    private(set) var preparedLanguages: [CoachLanguage] = []
    private(set) var resetCount = 0
    private var continuation: CheckedContinuation<Int, Never>?

    init(available: Bool) { self.available = available }

    func prepare(language: CoachLanguage) { preparedLanguages.append(language) }
    func reset() { resetCount += 1 }

    func select(from choices: [LiveCoachChoice], context: LiveCoachContext,
                language: CoachLanguage) async throws -> Int {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }

    func finish(index: Int) {
        continuation?.resume(returning: index)
        continuation = nil
    }
}
