import ActivityKit
import Foundation
import Observation

/// What the Live Activity should do as the session model moves. Pure, so it is unit-tested without
/// ActivityKit: the activity exists exactly while the stage is `.capturing`.
nonisolated enum SetLiveActivityRules {
    enum Step: Equatable {
        case none
        case start(exercise: ExerciseKind, reps: Int)
        case update(reps: Int)
        case end
    }

    static func step(from previous: WorkoutStage?, to stage: WorkoutStage, exercise: ExerciseKind,
                     reps: Int, isRunning: Bool) -> Step {
        let capturing = stage == .capturing
        switch (isRunning, capturing) {
        case (false, true): return .start(exercise: exercise, reps: reps)
        case (true, false): return .end
        case (true, true): return .update(reps: reps)
        case (false, false): return .none
        }
    }
}

/// Starts a Live Activity when a set starts, counts its reps, and ends it when the set ends. It
/// follows the session model with Observation, like the watch does, so the model knows nothing
/// about ActivityKit. Everything is local: no push token is requested.
@MainActor
final class SetLiveActivity {
    private weak var model: WorkoutSessionModel?
    private let demoInput: Bool
    private var activity: Activity<PlumbSetActivityAttributes>?
    private var lastReps = -1
    private var lastStage: WorkoutStage?

    init(demoInput: Bool) {
        self.demoInput = demoInput
    }

    /// Follows `model` for the app's lifetime. Any activity left from an earlier run (the app was
    /// killed mid-set) is ended first, so the Lock Screen never shows a set that is not running.
    func attach(to model: WorkoutSessionModel) {
        guard self.model == nil else { return }
        self.model = model
        endStaleActivities()
        follow()
    }

    private func follow() {
        guard let model else { return }
        let (stage, exercise, reps) = withObservationTracking {
            (model.stage, model.captureExercise, model.liveRepCount)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.follow() }
        }
        apply(SetLiveActivityRules.step(from: lastStage, to: stage, exercise: exercise, reps: reps,
                                        isRunning: activity != nil))
        lastStage = stage
    }

    private func apply(_ step: SetLiveActivityRules.Step) {
        switch step {
        case .none:
            break
        case .start(let exercise, let reps):
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let attributes = PlumbSetActivityAttributes(exerciseName: exercise.definition.copy.name,
                                                        startedAt: .now, demoInput: demoInput)
            let content = ActivityContent(state: .init(reps: reps), staleDate: nil)
            activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
            lastReps = reps
        case .update(let reps):
            guard reps != lastReps, let activity else { return }
            lastReps = reps
            Task { await activity.update(ActivityContent(state: .init(reps: reps), staleDate: nil)) }
        case .end:
            guard let activity else { return }
            self.activity = nil
            let final = ActivityContent(state: .init(reps: max(0, lastReps)), staleDate: nil)
            Task { await activity.end(final, dismissalPolicy: .immediate) }
        }
    }

    private func endStaleActivities() {
        for stale in Activity<PlumbSetActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
