import ActivityKit
import Foundation
import Observation
import os

/// what the Live Activity should do as the session model moves. Pure, so it is unit-tested without
/// activityKit: the activity exists exactly while the stage is `.capturing`
nonisolated enum SetLiveActivityRules {
    enum Step: Equatable {
        case none
        case start(exercise: ExerciseKind, reps: Int)
        case update(reps: Int)
        case end
    }

    static func step(
        from previous: WorkoutStage?,
        to stage: WorkoutStage,
        exercise: ExerciseKind,
        reps: Int,
        isRunning: Bool
    ) -> Step {
        let capturing = stage == .capturing
        switch (isRunning, capturing) {
        case (false, true):
            return .start(exercise: exercise, reps: reps)
        case (true, false):
            return .end
        case (true, true):
            return .update(reps: reps)
        case (false, false):
            return .none
        }
    }
}

/// starts a Live Activity when a set starts, counts its reps, and ends it when the set ends. It
/// follows the session model with Observation, like the watch does, so the model knows nothing
/// about ActivityKit. Everything is local: no push token is requested.
@MainActor
final class SetLiveActivity {
    private static let log = Logger(subsystem: "ai.mwm.build.challenge.team.08", category: "LiveActivity")
    private weak var model: WorkoutSessionModel?
    private var demoInput = false
    private var activity: Activity<FinnSetActivityAttributes>?
    private var lastReps = -1
    private var lastStage: WorkoutStage?

    /// follows `model` for the app's lifetime. Any activity left from an earlier run (the app was
    /// killed mid-set) is ended first, so the Lock Screen never shows a set that is not running
    func attach(to model: WorkoutSessionModel, demoInput: Bool) {
        guard self.model == nil else {
            return
        }
        self.model = model
        self.demoInput = demoInput
        endStaleActivities()
        follow()
    }

    private func follow() {
        guard let model else {
            return
        }
        let (stage, exercise, reps) = withObservationTracking {
            (model.stage, model.captureExercise, model.liveRepCount)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.follow() }
        }
        apply(SetLiveActivityRules.step(
            from: lastStage,
            to: stage,
            exercise: exercise,
            reps: reps,
            isRunning: activity != nil
        ))
        lastStage = stage
    }

    private func apply(_ step: SetLiveActivityRules.Step) {
        switch step {
        case .none:
            break
        case .start(let exercise, let reps):
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                return
            }
            let attributes = FinnSetActivityAttributes(
                exerciseName: exercise.definition.copy.name,
                startedAt: .now,
                demoInput: demoInput
            )
            let content = ActivityContent(
                state: FinnSetActivityAttributes.ContentState(reps: reps),
                staleDate: nil
            )
            activity = request(attributes, content)
            lastReps = reps
        case .update(let reps):
            guard reps != lastReps, let activity else {
                return
            }
            lastReps = reps
            Task { await activity.update(ActivityContent(
                state: FinnSetActivityAttributes.ContentState(reps: reps),
                staleDate: nil
            )) }
        case .end:
            guard let activity else {
                return
            }
            self.activity = nil
            let final = ActivityContent(
                state: FinnSetActivityAttributes.ContentState(reps: max(0, lastReps)),
                staleDate: nil
            )
            Task { await activity.end(final, dismissalPolicy: .immediate) }
        }
    }

    #if DEBUG
        /// a sample activity for simulator screenshots (`-finn-ui-live-activity-sample`), labelled DEMO
        /// never a real count: it stands for no set
        func showSample() {
            guard ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else {
                return
            }
            let attributes = FinnSetActivityAttributes(
                exerciseName: "Squat",
                startedAt: .now.addingTimeInterval(-48),
                demoInput: true
            )
            let content = ActivityContent(
                state: FinnSetActivityAttributes.ContentState(reps: 7),
                staleDate: nil
            )
            activity = request(attributes, content)
            lastReps = 7
        }
    #endif

    private func request(
        _ attributes: FinnSetActivityAttributes,
        _ content: ActivityContent<FinnSetActivityAttributes.ContentState>
    )
        -> Activity<FinnSetActivityAttributes>? {
        do {
            return try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            Self.log.error("Live Activity refused: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func endStaleActivities() {
        for stale in Activity<FinnSetActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
