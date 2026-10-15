import Foundation
import Observation

/// What a command from the watch does to the set.
nonisolated enum WatchCommandAction: Equatable, Sendable {
    case beginSet
    case endSet
    case ignore
}

/// What the watch shows for the iPhone's set, which taps it plays, and what a wrist command may do.
nonisolated enum WatchSyncRules {
    static func stage(for stage: WorkoutStage) -> WatchStage {
        switch stage {
        case .ready, .openingCamera, .error: .ready
        case .framing: .framing
        case .countdown: .countdown
        case .capturing: .capturing
        case .analyzing: .analyzing
        case .result: .result
        }
    }

    /// One line about a reviewed set: the measured reps and, when the set has one, its observation.
    static func summary(for result: WorkoutResult?, cueDismissed: Bool) -> String? {
        switch result {
        case .measured(let analysis, let cue):
            let count = analysis.reps.count
            let reps = String(localized: "\(count) reps measured.")
            guard let cue, !cueDismissed else { return reps }
            return "\(reps) \(cue.observation)"
        case .insufficientView, .failed:
            return String(localized: "Plumb couldn’t measure this set. The reason is on your iPhone.")
        case .interrupted:
            return String(localized: "The set stopped before it was complete.")
        case nil:
            return nil
        }
    }

    static func state(stage: WorkoutStage, exercise: ExerciseKind, liveReps: Int, caption: String?,
                      result: WorkoutResult?, cueDismissed: Bool, handsFree: Bool,
                      demoInput: Bool, measuresHeartRate: Bool = false) -> WatchState {
        let watchStage = Self.stage(for: stage)
        var state = WatchState(
            stage: watchStage,
            exercise: exercise.definition.copy.name,
            wristControls: AccessoryRoles.role(of: .appleWatch, for: exercise).offers(.startStopFromWrist),
            handsFree: handsFree,
            demoInput: demoInput,
            // Demo input films nobody, so there is no heart rate to pair with it.
            measuresHeartRate: measuresHeartRate && !demoInput)
        switch watchStage {
        case .countdown:
            if case .countdown(let seconds) = stage { state.countdown = seconds }
        case .capturing, .analyzing:
            state.reps = liveReps
            state.caption = caption
        case .result:
            if case .measured(let analysis, _) = result { state.reps = analysis.reps.count }
            state.summary = summary(for: result, cueDismissed: cueDismissed)
        case .ready, .framing:
            break
        }
        return state
    }

    /// The tap for going from `previous` to `next`: the set starting or ending, a live observation,
    /// or a counted rep. One tap per update; an observation outranks the rep it came with.
    static func haptic(from previous: WatchState?, to next: WatchState) -> WatchHaptic {
        guard let previous else { return .none }
        if next.stage == .capturing && previous.stage != .capturing { return .start }
        if previous.stage == .capturing && next.stage != .capturing { return .end }
        guard next.stage == .capturing else { return .none }
        if let caption = next.caption, caption != previous.caption { return .observation }
        if next.reps > previous.reps { return .rep }
        return .none
    }

    /// Start only while framing and stop only while the set runs, and only for exercises whose
    /// hands are free to press the watch.
    static func action(for command: WatchCommand, stage: WorkoutStage, exercise: ExerciseKind) -> WatchCommandAction {
        guard AccessoryRoles.role(of: .appleWatch, for: exercise).offers(.startStopFromWrist) else { return .ignore }
        switch (command, stage) {
        case (.startSet, .framing): return .beginSet
        case (.stopSet, .capturing): return .endSet
        default: return .ignore
        }
    }

    /// Two states show the same screen, whatever their tap and time.
    static func sameScreen(_ lhs: WatchState, _ rhs: WatchState) -> Bool {
        var lhs = lhs
        var rhs = rhs
        lhs.haptic = .none
        rhs.haptic = .none
        lhs.sentAt = 0
        rhs.sentAt = 0
        return lhs == rhs
    }
}

/// Keeps a watch in step with the iPhone's set and lets it start and stop sets. It follows the
/// session model with Observation, so the model knows nothing about the watch, and it knows nothing
/// about WatchConnectivity: `deliver` hands each new state to `WatchBridge`.
@MainActor
final class WatchSync {
    private weak var model: WorkoutSessionModel?
    private let demoInput: Bool
    private let clock: () -> Double
    private let deliver: (WatchState) -> Void
    /// The latest state handed to `deliver`.
    private(set) var lastSent: WatchState?

    init(model: WorkoutSessionModel, demoInput: Bool = false,
         clock: @escaping () -> Double = { Date().timeIntervalSince1970 },
         deliver: @escaping (WatchState) -> Void) {
        self.model = model
        self.demoInput = demoInput
        self.clock = clock
        self.deliver = deliver
        follow()
    }

    /// The screen shown now, without a tap, for a watch that just opened Plumb.
    var current: WatchState? {
        guard var state = lastSent else { return nil }
        state.haptic = .none
        return state
    }

    func handle(_ heartRate: WatchHeartRate) {
        model?.receiveHeartRate(heartRate.beatsPerMinute, at: Date(timeIntervalSince1970: heartRate.measuredAt))
    }

    func handle(_ command: WatchCommand) {
        guard let model else { return }
        switch WatchSyncRules.action(for: command, stage: model.stage, exercise: model.captureExercise) {
        case .beginSet:
            // The person is at their spot, as with a hands-free start.
            let countdown = model.handsFreeCountdown
            Task { await model.beginSet(countdown: countdown) }
        case .endSet:
            let tappedAt = ContinuousClock.now
            Task { await model.endSet(tappedAt: tappedAt) }
        case .ignore:
            break
        }
    }

    private func follow() {
        guard let model else { return }
        let state = withObservationTracking {
            Self.state(of: model, demoInput: demoInput)
        } onChange: { [weak self] in
            // Called before the change lands; read the new values on the next turn.
            Task { @MainActor [weak self] in self?.follow() }
        }
        publish(state)
    }

    private func publish(_ state: WatchState) {
        if let lastSent, WatchSyncRules.sameScreen(lastSent, state) { return }
        var next = state
        next.haptic = model?.hapticFeedback == .off ? .none : WatchSyncRules.haptic(from: lastSent, to: state)
        next.sentAt = max(clock(), (lastSent?.sentAt ?? 0) + 0.001)
        lastSent = next
        deliver(next)
    }

    private static func state(of model: WorkoutSessionModel, demoInput: Bool) -> WatchState {
        let exercise: ExerciseKind
        switch model.stage {
        case .ready, .openingCamera, .error: exercise = model.selectedExercise
        case .result: exercise = model.resultExercise
        case .framing, .countdown, .capturing, .analyzing: exercise = model.captureExercise
        }
        return WatchSyncRules.state(stage: model.stage, exercise: exercise, liveReps: model.liveRepCount,
                                    caption: model.liveCaption, result: model.result,
                                    cueDismissed: model.cueDismissed, handsFree: model.handsFree,
                                    demoInput: demoInput, measuresHeartRate: model.personalizesWithHealth)
    }
}
