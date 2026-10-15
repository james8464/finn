import Foundation

/// The Apple Health workout type of a Finn exercise. It mirrors `HKWorkoutActivityType` without
/// importing HealthKit, so this logic compiles and is tested everywhere; `HealthKitWorkoutExporter`
/// maps it to HealthKit.
nonisolated enum FitnessActivity: String, Equatable, Sendable {
    /// `HKWorkoutActivityType.functionalStrengthTraining`: Apple documents it as "strength training,
    /// primarily with free weights and body weight".
    case functionalStrengthTraining
}

nonisolated extension ExerciseKind {
    /// The Health workout type for a set of this exercise.
    ///
    /// The bodyweight squat, push-up, static lunge, pull-up and bar muscle-up are body-weight strength
    /// exercises, and the
    /// stiff-leg deadlift is done with body weight or free weights (Finn cannot see a load), which
    /// is exactly Apple's functional strength training. `traditionalStrengthTraining` is "primarily
    /// using machines or free weights", which an unloaded set is not; `crossTraining` mixes cardio,
    /// strength and flexibility, and `mixedCardio` is cardio. Neither describes a strength set.
    var fitnessActivity: FitnessActivity {
        switch self {
        case .bodyweightSquat, .pushUp, .staticLunge, .stiffLegDeadlift, .pullUp, .muscleUp: .functionalStrengthTraining
        }
    }
}

/// A value Finn writes in its own workout metadata. HealthKit takes string keys with string,
/// number or date values only; the HealthKit glue turns these into `NSString` and `NSNumber`.
nonisolated enum FitnessMetadataValue: Equatable, Sendable {
    case text(String)
    case number(Int)
}

/// One finished Finn session as an Apple Health workout, so it appears in the Fitness app's
/// workout history and in Health. It holds only what Finn measured: when the sets happened, how
/// many, the measured reps and the exercises. Never energy or heart rate: Finn measures neither
/// and must not estimate calories.
nonisolated struct FitnessWorkout: Equatable, Sendable {
    let sessionID: UUID
    let activity: FitnessActivity
    let start: Date
    let end: Date
    /// Breaks between two sets beyond `longestRest`, saved as pause and resume events so they do not
    /// count as workout time (Apple counts an iPhone workout's duration towards the Exercise ring).
    let pauses: [DateInterval]
    /// Measured sets: sets with at least one measured rep.
    let setCount: Int
    let measuredReps: Int
    /// Exercise names in the order they were first done, each once.
    let exerciseNames: [String]

    /// Finn sets are filmed with the iPhone propped up a few steps away, at home or in a gym.
    var isIndoor: Bool { true }

    /// Rest between sets that still counts as workout time. A strength workout includes its rests,
    /// as Apple Watch records them; a longer break (the person left the app open) is paused after it.
    static let longestRest: TimeInterval = 5 * 60
    /// A set capture stops after two minutes (`CameraPoseSource`); a longer rep span is not usable.
    static let longestSet: TimeInterval = 120

    static let setCountKey = "FinnSetCount"
    static let measuredRepsKey = "FinnMeasuredReps"
    static let exercisesKey = "FinnExercises"
    /// HealthKit replaces a saved object only by a greater sync version; Finn saves each session once.
    static let syncVersion = 1

    /// Finn's own metadata. The HealthKit glue adds the indoor flag and the sync identifier.
    var finnMetadata: [String: FitnessMetadataValue] {
        [
            Self.setCountKey: .number(setCount),
            Self.measuredRepsKey: .number(measuredReps),
            Self.exercisesKey: .text(exerciseNames.joined(separator: ", ")),
        ]
    }

    /// HealthKit's sync identifier: one workout per Finn session, even if a save were repeated.
    var syncIdentifier: String { "ai.mwm.build.challenge.team.08.session.\(sessionID.uuidString)" }

    /// Time counted as workout, without the pauses.
    var activeDuration: TimeInterval {
        end.timeIntervalSince(start) - pauses.reduce(0) { $0 + $1.duration }
    }

    /// The workout for a session, or nil when no set of it was measured.
    ///
    /// Each set is placed from its capture time (`capturedAt`, saved when the set ended) back over
    /// the span of its measured reps. Rep times share one clock within a set but not across sets, so
    /// only their differences are used. The workout runs from the first set's first measured rep to
    /// the end of the last set, rests included, with breaks beyond `longestRest` paused.
    static func make(from session: WorkoutSessionSummary) -> FitnessWorkout? {
        let measured = session.sets
            .filter { !$0.analysis.reps.isEmpty }
            .sorted { $0.capturedAt < $1.capturedAt }
        guard let first = measured.first, let last = measured.last else { return nil }
        let spans = measured.map { set in
            DateInterval(start: set.capturedAt.addingTimeInterval(-repSpan(of: set)), end: set.capturedAt)
        }
        var pauses: [DateInterval] = []
        var latestEnd = spans[0].end
        for span in spans.dropFirst() {
            let restEnds = latestEnd.addingTimeInterval(longestRest)
            if span.start > restEnds {
                pauses.append(DateInterval(start: restEnds, end: span.start))
            }
            latestEnd = max(latestEnd, span.end)
        }
        let start = spans.map(\.start).min() ?? first.capturedAt
        let end = last.capturedAt
        guard end > start else { return nil }
        var names: [String] = []
        for set in measured {
            let name = set.exercise.definition.copy.name
            if !names.contains(name) { names.append(name) }
        }
        return FitnessWorkout(
            sessionID: session.id,
            activity: mostFrequentActivity(in: measured),
            start: start,
            end: end,
            pauses: pauses,
            setCount: measured.count,
            measuredReps: measured.reduce(0) { $0 + $1.analysis.reps.count },
            exerciseNames: names
        )
    }

    /// From the first measured rep's start to the last one's end, clamped to a set's capture limit.
    private static func repSpan(of set: SetSummary) -> TimeInterval {
        guard let firstStart = set.analysis.reps.map(\.startTime).min(),
              let lastEnd = set.analysis.reps.map(\.endTime).max() else { return 0 }
        let span = lastEnd - firstStart
        guard span.isFinite, span > 0 else { return 0 }
        return min(span, longestSet)
    }

    /// One workout has one type: the one of most measured sets, the earliest on a tie.
    private static func mostFrequentActivity(in sets: [SetSummary]) -> FitnessActivity {
        let activities = sets.map(\.exercise.fitnessActivity)
        var counts: [FitnessActivity: Int] = [:]
        for activity in activities { counts[activity, default: 0] += 1 }
        let most = counts.values.max() ?? 0
        return activities.first { counts[$0] == most } ?? .functionalStrengthTraining
    }
}

/// The Apple Health workout saved for a session, kept in the saved session so it is saved once.
nonisolated struct FitnessWorkoutRecord: Codable, Equatable, Sendable {
    let savedAt: Date
    /// The HealthKit workout's identifier. Nil when Health saved the workout while the iPhone was
    /// locked: `HKWorkoutBuilder.finishWorkout()` then succeeds without returning it.
    let workoutID: UUID?
}

/// Whether Finn may save workouts to Apple Health. HealthKit tells an app whether it may share
/// (write) a type, never whether it may read one; Finn only asks to share workouts.
nonisolated enum FitnessAuthorization: Equatable, Sendable {
    /// Health is not on this device, or is restricted.
    case unavailable
    case notDetermined
    case denied
    case authorized
}

nonisolated enum FitnessSaveError: Error, Equatable {
    /// Health refused the save: permission was turned off since it was last checked.
    case notAuthorized
    /// Health is not available or is restricted on this device.
    case unavailable
}

/// What happened to the latest save to Apple Health, shown in one short line.
nonisolated enum FitnessSaveStatus: Equatable, Sendable {
    case saving
    case saved
    case failed
    case needsPermission
    case unavailable

    var text: String {
        switch self {
        case .saving: String(localized: "Saving to Fitness…")
        case .saved: String(localized: "Saved to Fitness")
        case .failed: String(localized: "Couldn’t save to Fitness")
        case .needsPermission: String(localized: "Allow Finn in Health settings")
        case .unavailable: String(localized: "Apple Health isn’t available on this iPhone")
        }
    }

    /// Saving again can help: the save failed, or Health has not allowed it yet.
    var offersRetry: Bool { self == .failed || self == .needsPermission }
}

/// The latest save to Apple Health and the session it concerns.
nonisolated struct FitnessSaveReport: Equatable, Sendable {
    let sessionID: UUID
    let status: FitnessSaveStatus
}

/// Saves a finished session to Apple Health as a workout. The app uses HealthKit
/// (`HealthKitWorkoutExporter`); tests use a fake.
protocol FitnessWorkoutSaving: AnyObject {
    /// Health's current permission for Finn to save workouts. Reading it never prompts.
    var authorisation: FitnessAuthorization { get }
    /// Shows Health's permission sheet when the person has not answered yet; returns the result.
    func requestAuthorization() async -> FitnessAuthorization
    /// Saves the workout and returns its HealthKit identifier when Health gives it back. Throws
    /// `FitnessSaveError` when Health refuses, or the underlying error.
    func save(_ workout: FitnessWorkout) async throws -> UUID?
}
