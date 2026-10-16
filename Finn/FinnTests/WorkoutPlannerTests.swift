import Foundation
import Testing
@testable import Finn

@MainActor
struct WorkoutPlannerTests {
    private func rep(_ number: Int) -> RepMetric {
        RepMetric(
            number: number,
            startTime: Double(number) * 2,
            endTime: Double(number) * 2 + 1.5,
            relativeRange: 0.4
        )
    }

    private func session(
        _ exercise: ExerciseKind,
        reps: Int,
        daysAgo: Int,
        now: Date,
        confidence: Double = 0.95,
        partlyVisible: Bool = false
    ) -> WorkoutSessionSummary {
        let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
        let id = UUID()
        let set = SetSummary(
            id: UUID(),
            sessionID: id,
            capturedAt: date,
            bodySide: .left,
            analysis: SetAnalysis(
                reps: (1 ... reps).map(rep),
                confidence: confidence,
                rubricVersion: "test"
            ),
            cue: nil,
            cueResponse: .unanswered,
            exercise: exercise,
            cameraView: .side,
            partlyVisible: partlyVisible
        )
        return WorkoutSessionSummary(id: id, startedAt: date, sets: [set])
    }

    @Test func emptyHistoryGivesAFullWorkoutWithoutMuscleUp() {
        let plan = WorkoutPlanner.make(history: [])
        #expect(plan.exercises.count == 4)
        #expect(!plan.exercises.contains { $0.exercise == .muscleUp })
        #expect(plan.exercises.allSatisfy { $0.sets == 3 && $0.reps >= 1 && !$0.isDone })
    }

    @Test func coversEachMuscleGroup() {
        let kinds = Set(WorkoutPlanner.make(history: []).exercises.map(\.exercise))
        #expect(kinds.contains(.pushUp))
        #expect(kinds.contains(.pullUp))
        #expect(!kinds.isDisjoint(with: [.bodyweightSquat, .staticLunge, .stiffLegDeadlift]))
    }

    @Test func prefersTheExerciseDoneLongestAgo() {
        let now = Date()
        let history = [session(.bodyweightSquat, reps: 10, daysAgo: 1, now: now),
                       session(.staticLunge, reps: 8, daysAgo: 6, now: now),
                       session(.stiffLegDeadlift, reps: 8, daysAgo: 3, now: now)]
        let plan = WorkoutPlanner.make(history: history, now: now)
        #expect(plan.exercises.first?.exercise == .staticLunge)
    }

    @Test func repsFollowTheBestMeasuredSetWithinBounds() {
        let now = Date()
        let plan = WorkoutPlanner.make(history: [session(.pushUp, reps: 30, daysAgo: 2, now: now)], now: now)
        #expect(plan.exercises.first { $0.exercise == .pushUp }?.reps == 20)
    }

    @Test func muscleUpAppearsOnlyAfterTenPullUps() {
        let now = Date()
        let few = WorkoutPlanner.make(history: [session(.pullUp, reps: 9, daysAgo: 2, now: now)], now: now)
        #expect(!few.exercises.contains { $0.exercise == .muscleUp })
        let many = WorkoutPlanner.make(history: [session(.pullUp, reps: 10, daysAgo: 2, now: now)], now: now)
        #expect(many.exercises.contains { $0.exercise == .muscleUp })
    }

    @Test func uncertainPartialAndFutureSetsCannotUnlockMuscleUp() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let untrusted = [
            session(.pullUp, reps: 15, daysAgo: 1, now: now, confidence: 0.4),
            session(.pullUp, reps: 15, daysAgo: 1, now: now, partlyVisible: true),
            session(.pullUp, reps: 15, daysAgo: -1, now: now)
        ]
        for saved in untrusted {
            let workout = WorkoutPlanner.make(history: [saved], now: now)
            #expect(!workout.exercises.contains { $0.exercise == .muscleUp })
        }
    }

    @Test func currentCapacityWinsOverOldPersonalBest() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let older = session(.pushUp, reps: 20, daysAgo: 30, now: now)
        let current = session(.pushUp, reps: 5, daysAgo: 1, now: now)
        let workout = WorkoutPlanner.make(history: [older, current], now: now)
        let pushUp = try #require(workout.exercises.first { $0.exercise == .pushUp })
        #expect(pushUp.reps == 5)
    }

    @Test func storeKeepsAValidatedWorkoutUntickedAndOnlyOnce() {
        let defaults = UserDefaults(suiteName: "WorkoutPlannerTests.\(UUID().uuidString)")!
        let store = PlannedWorkoutStore(defaults: defaults)
        var plan = WorkoutPlanner.make(history: [])
        for index in plan.exercises.indices {
            plan.exercises[index].isDone = true
        }
        #expect(plan.isComplete)
        store.add(plan)
        store.add(plan)
        #expect(store.upcoming.count == 1)
        #expect(store.upcoming[0].exercises.allSatisfy { !$0.isDone })
        #expect(store.upcoming[0].lastDoneAt != nil)
        #expect(PlannedWorkoutStore(defaults: defaults).upcoming.count == 1)
    }
}
