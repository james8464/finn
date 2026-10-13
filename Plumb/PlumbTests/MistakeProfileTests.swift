import Foundation
import Testing
@testable import Plumb

nonisolated struct MistakeProfileTests {
    private func set(_ exercise: ExerciseKind = .bodyweightSquat, issues: [SetIssue]?,
                     minutesAgo: Double) -> SetSummary {
        SetSummary(id: UUID(), sessionID: UUID(), capturedAt: Date(timeIntervalSince1970: 1_000_000 - minutesAgo * 60),
                   bodySide: .left,
                   analysis: SetAnalysis(reps: [RepMetric(number: 1, startTime: 0, endTime: 2, relativeRange: 0.4)],
                                         confidence: 0.9, rubricVersion: SquatRubric.version),
                   cue: nil, cueResponse: .unanswered, exercise: exercise, issues: issues)
    }

    private func history(_ sets: [SetSummary]) -> [WorkoutSessionSummary] {
        [WorkoutSessionSummary(id: UUID(), startedAt: Date(timeIntervalSince1970: 0), sets: sets)]
    }

    @Test func theIssueSeenInMostRecentSetsIsTheFocus() {
        let sets = [
            set(issues: [.shallowMovements], minutesAgo: 1),
            set(issues: [.shallowMovements, .spedUp], minutesAgo: 2),
            set(issues: [], minutesAgo: 3),
            set(issues: [.spedUp], minutesAgo: 4),
            set(issues: [.shallowMovements], minutesAgo: 5),
        ]
        let profile = MistakeProfile.make(history: history(sets), exercise: .bodyweightSquat)
        #expect(profile?.issue == .shallowMovements)
        #expect(profile?.sets == 3)
        #expect(profile?.outOf == 5)
        #expect(profile?.summary == "Movements too shallow to count in 3 of your last 5 squat sets.")
        #expect(profile?.focus == "Reach the same depth on every rep. Plumb needs hips 15% of your leg length down to count one.")
    }

    @Test func aPatternSeenOnceIsNotAFocus() {
        let sets = [set(issues: [.angledView], minutesAgo: 1), set(issues: [], minutesAgo: 2)]
        #expect(MistakeProfile.make(history: history(sets), exercise: .bodyweightSquat) == nil)
    }

    @Test func aRarePatternInManySetsIsNotAFocus() {
        // Two of ten sets is under the 30% share.
        var sets = (0..<8).map { set(issues: [], minutesAgo: Double($0)) }
        sets += [set(issues: [.outsideTempo], minutesAgo: 20), set(issues: [.outsideTempo], minutesAgo: 21)]
        #expect(MistakeProfile.make(history: history(sets), exercise: .bodyweightSquat) == nil)
    }

    @Test func onlyTheSameExerciseCounts() {
        let sets = [
            set(.pushUp, issues: [.rangeDropped], minutesAgo: 1),
            set(.pushUp, issues: [.rangeDropped], minutesAgo: 2),
            set(issues: [], minutesAgo: 3),
        ]
        #expect(MistakeProfile.make(history: history(sets), exercise: .bodyweightSquat) == nil)
        let pushUp = MistakeProfile.make(history: history(sets), exercise: .pushUp)
        #expect(pushUp?.summary == "Elbow bend smaller at the end of the set in 2 of your last 2 push-up sets.")
        #expect(pushUp?.focus == ExerciseDefinition.pushUp.copy.nextAction)
    }

    @Test func setsSavedBeforeIssuesExistedAreLeftOut() {
        let sets = [
            set(issues: nil, minutesAgo: 1), set(issues: nil, minutesAgo: 2),
            set(issues: [.unfinishedLastRep], minutesAgo: 3), set(issues: [.unfinishedLastRep], minutesAgo: 4),
        ]
        let profile = MistakeProfile.make(history: history(sets), exercise: .bodyweightSquat)
        #expect(profile?.outOf == 2)
        #expect(profile?.issue == .unfinishedLastRep)
    }

    @Test func issuesComeFromTheDiagnosticsTheObservationAndLiveEvents() {
        var diagnostics = MovementDiagnostics(requiredDepth: 0.15)
        diagnostics.shallow = 2
        diagnostics.unfinished = true
        diagnostics.angledView = 40
        let cue = Cue(kind: .rangeDecreased, repNumbers: [5, 6], earlierMedian: 0.4, laterMedian: 0.3,
                      observation: "", nextAction: "")
        #expect(SetIssue.issues(diagnostics: diagnostics, cue: cue, spedUp: true)
                == [.shallowMovements, .unfinishedLastRep, .angledView, .rangeDropped, .spedUp])
        #expect(SetIssue.issues(diagnostics: MovementDiagnostics(requiredDepth: 0.15), cue: nil, spedUp: false).isEmpty)
    }

    @Test func oldSummariesWithoutIssuesStillDecode() throws {
        let saved = set(issues: [.spedUp], minutesAgo: 0)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as! [String: Any]
        json.removeValue(forKey: "issues")
        let decoded = try JSONDecoder().decode(SetSummary.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.issues == nil)
        #expect(decoded.id == saved.id)
    }
}
