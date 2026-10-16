import Foundation
import Testing
@testable import Finn

struct PostureGuideTests {
    private func set(
        _ exercise: ExerciseKind,
        at date: Date,
        measurements: [FormMeasurement]? = nil,
        partlyVisible: Bool? = nil,
        issues: [SetIssue]? = nil
    ) -> SetSummary {
        let reps = (1 ... 6).map {
            RepMetric(
                number: $0,
                startTime: Double($0),
                endTime: Double($0) + 1,
                relativeRange: 0.4
            )
        }
        return SetSummary(
            id: UUID(),
            sessionID: UUID(),
            capturedAt: date,
            bodySide: .left,
            analysis: SetAnalysis(
                reps: reps,
                confidence: 0.9,
                rubricVersion: "squat-side-v7"
            ),
            cue: nil,
            cueResponse: .unanswered,
            exercise: exercise,
            issues: issues,
            formMeasurements: measurements,
            partlyVisible: partlyVisible
        )
    }

    @Test func usesLatestSetForChosenExercise() {
        let old = set(.bodyweightSquat, at: Date(timeIntervalSince1970: 10))
        let other = set(.pushUp, at: Date(timeIntervalSince1970: 30))
        let latest = set(.bodyweightSquat, at: Date(timeIntervalSince1970: 20))
        let history = [WorkoutSessionSummary(
            id: UUID(),
            startedAt: .now,
            sets: [old, other, latest]
        )]
        #expect(PostureGuideEvidence.make(for: .bodyweightSquat, history: history).latest?.id == latest.id)
    }

    @Test func unclearSetDoesNotProduceFormComparison() {
        let measurement = FormMeasurement(check: .squatDepth, judged: 6, faulty: 5, typical: 35)
        let unclear = set(.bodyweightSquat, at: .now, measurements: [measurement], partlyVisible: true)
        let history = [WorkoutSessionSummary(id: UUID(), startedAt: .now, sets: [unclear])]
        let evidence = PostureGuideEvidence.make(for: .bodyweightSquat, history: history)
        #expect(evidence.latest?.id == unclear.id)
        #expect(evidence.measurements.isEmpty)
        #expect(evidence.flagged.isEmpty)
    }

    @Test func onlyRepeatedMeasuredFaultsNeedAChange() {
        let small = FormMeasurement(check: .squatDepth, judged: 8, faulty: 1, typical: 31)
        let repeated = FormMeasurement(check: .squatChestDrop, judged: 8, faulty: 4, typical: 48)
        let current = set(.bodyweightSquat, at: .now, measurements: [small, repeated])
        let history = [WorkoutSessionSummary(id: UUID(), startedAt: .now, sets: [current])]
        let evidence = PostureGuideEvidence.make(for: .bodyweightSquat, history: history)
        #expect(evidence.flagged.map(\.check) == [.squatChestDrop])
    }

    @Test func pullUpUsesMeasuredIssueWithoutClaimingSideViewFormChecks() {
        let current = set(.pullUp, at: .now, issues: [.rangeDropped])
        let history = [WorkoutSessionSummary(id: UUID(), startedAt: .now, sets: [current])]
        let evidence = PostureGuideEvidence.make(for: .pullUp, history: history)
        #expect(evidence.measurements.isEmpty)
        #expect(evidence.movementIssue == .rangeDropped)
        let unclear = set(.pullUp, at: .now, partlyVisible: true, issues: [.rangeDropped])
        #expect(PostureGuideEvidence.make(for: .pullUp, history: [
            WorkoutSessionSummary(id: UUID(), startedAt: .now, sets: [unclear])
        ]).movementIssue == nil)
    }
}
