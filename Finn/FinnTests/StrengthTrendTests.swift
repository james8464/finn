import Foundation
import Testing
@testable import Finn

struct StrengthTrendTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func set(_ exercise: ExerciseKind, reps: Int, at date: Date) -> SetSummary {
        let metrics = (0 ..< reps).map {
            RepMetric(number: $0 + 1, startTime: Double($0), endTime: Double($0) + 1, relativeRange: 0.4)
        }
        return SetSummary(
            id: UUID(),
            sessionID: UUID(),
            capturedAt: date,
            bodySide: .left,
            analysis: SetAnalysis(
                reps: metrics,
                confidence: 0.9,
                rubricVersion: "squat-side-v7"
            ),
            cue: nil,
            cueResponse: .unanswered,
            exercise: exercise
        )
    }

    /// one session a day for each rep count, newest first like the saved history
    private func history(
        _ bests: [Int],
        exercise: ExerciseKind = .bodyweightSquat
    ) -> [WorkoutSessionSummary] {
        bests.enumerated().map { day, reps in
            let date = calendar.date(byAdding: .day, value: day, to: start)!
            return WorkoutSessionSummary(
                id: UUID(),
                startedAt: date,
                sets: [set(exercise, reps: max(1, reps - 2), at: date),
                       set(exercise, reps: reps, at: date)]
            )
        }
        .reversed()
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start)!
    }

    @Test func keepsBestSetPerSessionOldestFirst() {
        let trend = StrengthTrend.make(
            for: .bodyweightSquat,
            history: history([8, 10, 9]),
            calendar: calendar
        )
        #expect(trend.points.map(\.value) == [8, 10, 9])
        #expect(trend.best == 10)
        #expect(trend.metric == .reps)
    }

    @Test func ignoresOtherExercises() {
        let trend = StrengthTrend.make(for: .pushUp, history: history([8, 10, 9]), calendar: calendar)
        #expect(trend.points.isEmpty)
        #expect(trend.best == nil)
        #expect(trend.projectionStatus == .needsWorkouts(3))
        #expect(trend.projection(to: .oneWeek, today: day(2), calendar: calendar) == nil)
    }

    @Test func noProjectionBeforeThreeWorkouts() {
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: history([8, 10]), calendar: calendar)
        #expect(trend.projectionStatus == .needsWorkouts(1))
        #expect(trend.projection(to: .oneWeek, today: day(1), calendar: calendar) == nil)
    }

    @Test func noProjectionWhenEveryWorkoutIsOnOneDay() {
        // three workouts minutes apart, like a demo run: no change over days to follow
        let morning = calendar.date(byAdding: .hour, value: 9, to: calendar.startOfDay(for: start))!
        let sessions = [6, 9, 12].enumerated().map { index, reps in
            let date = morning.addingTimeInterval(Double(index) * 600)
            return WorkoutSessionSummary(
                id: UUID(),
                startedAt: date,
                sets: [set(.bodyweightSquat, reps: reps, at: date)]
            )
        }
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: sessions, calendar: calendar)
        #expect(trend.projectionStatus == .needsMoreDays)
        #expect(trend.projection(to: .oneWeek, today: morning, calendar: calendar) == nil)
    }

    @Test func projectsLinearTrendDailyForAWeek() throws {
        // one more rep a day: a week after the last workout, seven more
        let trend = StrengthTrend.make(
            for: .bodyweightSquat,
            history: history([5, 6, 7, 8]),
            calendar: calendar
        )
        #expect(trend.projectionStatus == .ready)
        let projection = try #require(trend.projection(to: .oneWeek, today: day(3), calendar: calendar))
        #expect(projection.points.map(\.value) == [9, 10, 11, 12, 13, 14, 15])
        #expect(projection.points.map(\.date) == (4 ... 10).map { calendar.startOfDay(for: day($0)) })
        #expect(projection.target == 15)
    }

    @Test func roundsToWholeReps() throws {
        // half a rep a day from 5.17: 9.67 a week after the last workout
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: history([5, 6, 6]), calendar: calendar)
        let projection = try #require(trend.projection(to: .oneWeek, today: day(2), calendar: calendar))
        #expect(projection.points.allSatisfy { $0.value == $0.value.rounded() })
        #expect(projection.target == 10)
    }

    @Test func neverProjectsBelowTheCurrentBest() throws {
        let trend = StrengthTrend.make(
            for: .bodyweightSquat,
            history: history([12, 8, 4]),
            calendar: calendar
        )
        let projection = try #require(trend.projection(to: .twoWeeks, today: day(2), calendar: calendar))
        #expect(projection.points.allSatisfy { $0.value == 12 })
    }

    @Test func monthHorizonsEndOnTheCalendarDate() throws {
        let trend = StrengthTrend.make(for: .bodyweightSquat, history: history([5, 6, 7]), calendar: calendar)
        let today = day(2)
        for (horizon, months) in [(ProgressHorizon.oneMonth, 1), (.twoMonths, 2)] {
            let projection = try #require(trend.projection(to: horizon, today: today, calendar: calendar))
            #expect(projection.points.count == horizon.barCount)
            #expect(projection.points.last?.date
                == calendar.date(byAdding: .month, value: months, to: calendar.startOfDay(for: today)))
            #expect(projection.points.map(\.date) == projection.points.map(\.date).sorted())
        }
    }
}
