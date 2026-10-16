import Foundation
import Observation

/// one exercise of a planned workout: what to do, not what was measured
nonisolated struct PlannedExercise: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let exercise: ExerciseKind
    let sets: Int
    let reps: Int
    var isDone: Bool
    var focus: String?

    init(id: UUID = UUID(), exercise: ExerciseKind, sets: Int, reps: Int, isDone: Bool = false, focus: String? = nil) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.isDone = isDone
        self.focus = focus
    }
}

/// a workout the Coach composed from the exercises Finn can measure
nonisolated struct PlannedWorkout: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    var exercises: [PlannedExercise]
    /// set when the person validated the workout in the Coach
    var lastDoneAt: Date?
    var planningSource: WorkoutPlanSource?
    var planningNote: String?

    init(id: UUID = UUID(), createdAt: Date = Date(), exercises: [PlannedExercise], lastDoneAt: Date? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.exercises = exercises
        self.lastDoneAt = lastDoneAt
    }

    var isComplete: Bool { !exercises.isEmpty && exercises.allSatisfy(\.isDone) }
    var doneCount: Int { exercises.filter(\.isDone).count }

    /// the same workout with every box unticked, ready to be followed again
    var reset: PlannedWorkout {
        var copy = self
        copy.exercises = exercises.map { PlannedExercise(exercise: $0.exercise, sets: $0.sets, reps: $0.reps, focus: $0.focus) }
        return copy
    }
}

/// composes a workout from the saved history alone: no model runs, so it works on every iPhone
nonisolated enum WorkoutPlanner {
    private enum Group { case lower, push, pull }

    private static func group(_ kind: ExerciseKind) -> Group {
        switch kind {
        case .bodyweightSquat, .staticLunge, .stiffLegDeadlift: .lower
        case .pushUp: .push
        case .pullUp, .muscleUp: .pull
        }
    }

    /// reps for a first set when nothing was measured yet
    private static func startingReps(_ kind: ExerciseKind) -> Int {
        switch kind {
        case .bodyweightSquat: 12
        case .pushUp: 8
        case .staticLunge: 8
        case .stiffLegDeadlift: 10
        case .pullUp: 4
        case .muscleUp: 1
        }
    }

    /// the most reps measured in one set of `kind`, nil when the person never did it
    private static func bestReps(_ kind: ExerciseKind, in sets: [SetSummary]) -> Int? {
        sets.filter { $0.exercise == kind }.map { $0.analysis.reps.count }.max()
    }

    /// Picks the exercise of each muscle group that was done longest ago, so a new workout covers
    /// what the last ones left out. The bar muscle-up only appears once the person has done it or
    /// pulls up ten times in a set.
    static func make(history: [WorkoutSessionSummary], now: Date = Date()) -> PlannedWorkout {
        let sets = history.flatMap(\.sets)
        func lastDone(_ kind: ExerciseKind) -> Date {
            sets.filter { $0.exercise == kind }.map(\.capturedAt).max() ?? .distantPast
        }
        func eligible(_ kind: ExerciseKind) -> Bool {
            guard kind == .muscleUp else { return true }
            return (bestReps(.muscleUp, in: sets) ?? 0) > 0 || (bestReps(.pullUp, in: sets) ?? 0) >= 10
        }
        func stalest(_ group: Group, skipping taken: Set<ExerciseKind> = []) -> ExerciseKind? {
            ExerciseKind.allCases
                .filter { Self.group($0) == group && eligible($0) && !taken.contains($0) }
                .min { lastDone($0) < lastDone($1) }
        }

        var picked: [ExerciseKind] = []
        for group in [Group.lower, .push, .pull] {
            if let kind = stalest(group) { picked.append(kind) }
        }
        if let extra = stalest(.lower, skipping: Set(picked)) { picked.append(extra) }

        let exercises = picked.map { kind -> PlannedExercise in
            let reps: Int
            if let best = bestReps(kind, in: sets), best > 0 {
                reps = min(max(best, 3), 20)
            } else {
                reps = startingReps(kind)
            }
            return PlannedExercise(exercise: kind, sets: 3, reps: reps)
        }
        return PlannedWorkout(createdAt: now, exercises: exercises)
    }
}

/// the workouts the person validated, kept on the device for the Workout tab's "Next workouts"
@MainActor @Observable
final class PlannedWorkoutStore {
    static let shared = PlannedWorkoutStore()

    private static let key = "plannedWorkouts.v1"
    private let defaults: UserDefaults
    private(set) var upcoming: [PlannedWorkout]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([PlannedWorkout].self, from: data) {
            var seen: Set<UUID> = []
            upcoming = saved.filter { workout in
                (1...6).contains(workout.exercises.count)
                    && Set(workout.exercises.map(\.id)).count == workout.exercises.count
                    && workout.exercises.allSatisfy { (1...3).contains($0.sets) && (1...20).contains($0.reps) }
                    && seen.insert(workout.id).inserted
            }
        } else {
            upcoming = []
        }
    }

    /// keeps a validated workout, unticked, at the top of the list; the same workout is not kept twice
    func add(_ workout: PlannedWorkout, doneAt: Date = Date()) {
        var kept = workout.reset
        kept.lastDoneAt = doneAt
        upcoming.removeAll { $0.id == workout.id }
        upcoming.insert(kept, at: 0)
        persist()
    }

    func remove(_ workout: PlannedWorkout) {
        upcoming.removeAll { $0.id == workout.id }
        persist()
    }

    func clear() {
        upcoming = []
        defaults.removeObject(forKey: Self.key)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(upcoming) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
