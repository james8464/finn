import Foundation
import Testing
@testable import Finn

struct StrengthTrendTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func set(_ exercise: ExerciseKind, reps: Int, at date: Date) -> SetSummary {
        let metrics = (0..<reps).map {
            RepMetric(number: $0 + 1, startTime: Double($0), endTime: Double($0) + 1, relativeRange: 0.4)
        }
        return SetSummary(id: UUID(), sessionID: UUID(), capturedAt: date, bodySide: .left,
                          analysis: SetAnalysis(reps: metrics, confidence: 0.9, rubricVersion: "squat-side-v7"),
                          cue: nil, cueResponse: .unanswered, exercise: exercise)
    }

    /// one session a day for each rep count, newest first like the saved history
    private func history(_ bests: [Int], exercise: ExerciseKind = .bodyweightSquat) -> [WorkoutSessionSummary] {
        bests.enumerated().map { day, reps in
            let date = calendar.date(byAdding: .day, value: day, to: start)!
            return WorkoutSessionSummary(id: UUID(), startedAt: date,
                                         sets: [set(exercise, reps: max(1, reps - 2), at: date),
                                                set(exercise, reps: reps, at: date)])
        }
        .reversed()
    }

    @Test func keepsBestSetPerSessionOldestFirst() {
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: history([8, 10, 9]), calendar: calendar)
        #expect(trend.points.map(\.value) == [8, 10, 9])
        #expect(trend.best == 10)
        #expect(trend.metric == .reps)
    }

    @Test func ignoresOtherExercises() {
        let trend = StrengthTrend.make(for: .pushUp, history: history([8, 10, 9]), calendar: calendar)
        #expect(trend.points.isEmpty)
        #expect(trend.best == nil)
        #expect(trend.projection.isEmpty)
    }

    @Test func noProjectionBeforeThreeTrainingDays() {
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: history([8, 10]), calendar: calendar)
        #expect(trend.projection.isEmpty)
        #expect(trend.fittedSessions == 0)
    }

    @Test func projectsLinearTrendFourWeeksFromLastPoint() throws {
        // one more rep a day: four weeks later, 28 more than the last session
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: history([5, 6, 7, 8]), calendar: calendar)
        let first = try #require(trend.projection.first)
        let end = try #require(trend.projection.last)
        #expect(first == trend.points.last)
        #expect(abs(end.value - 36) < 0.001)
        #expect(end.date == calendar.date(byAdding: .day, value: StrengthTrend.horizonDays, to: first.date))
        #expect(trend.fittedSessions == 4)
    }

    @Test func fitsOnlyTheRecentWindow() {
        // an old flat stretch is outside the eight-session window
        let bests = Array(repeating: 3, count: 6) + [10, 11, 12, 13, 14, 15, 16, 17]
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: history(bests), calendar: calendar)
        #expect(trend.fittedSessions == StrengthTrend.fitWindow)
        #expect(abs((trend.projection.last?.value ?? 0) - 45) < 0.001)
    }

    @Test func projectionNeverGoesBelowZero() {
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: history([12, 8, 4]), calendar: calendar)
        #expect(trend.projection.last?.value == 0)
    }
}
