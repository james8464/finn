import Foundation
import Observation

/// Maps the iPhone's measured set to a short Watch state.
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
            return String(localized: "Finn couldn’t measure this set. The reason is on your iPhone.")
        case .interrupted:
            return String(localized: "The set stopped before it was complete.")
        case nil:
            return nil
        }
    }

    static func state(stage: WorkoutStage, exercise: ExerciseKind, liveReps: Int, caption: String?,
                      result: WorkoutResult?, cueDismissed: Bool, handsFree: Bool,
                      demoInput: Bool, measuresHeartRate: Bool = false,
                      coachMessage: String? = nil) -> WatchState {
        let watchStage = Self.stage(for: stage)
        var state = WatchState(
            stage: watchStage,
            exercise: exercise.definition.copy.name,
            wristControls: false,
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
            if watchStage == .capturing { state.coachMessage = coachMessage }
        case .result:
            if case .measured(let analysis, _) = result { state.reps = analysis.reps.count }
            state.summary = summary(for: result, cueDismissed: cueDismissed)
        case .ready, .framing:
            break
        }
        return state
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

/// Keeps a watch in step with the iPhone's set. It follows the
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
    private var activeSetID: String?
    private var heartbeatTask: Task<Void, Never>?

    init(model: WorkoutSessionModel, demoInput: Bool = false,
         clock: @escaping () -> Double = { Date().timeIntervalSince1970 },
         deliver: @escaping (WatchState) -> Void) {
        self.model = model
        self.demoInput = demoInput
        self.clock = clock
        self.deliver = deliver
        follow()
    }

    /// The screen shown now, without a tap, for a watch that just opened Finn.
    var current: WatchState? {
        guard var state = lastSent else { return nil }
        state.haptic = .none
        return state
    }

    func handle(_ heartRate: WatchHeartRate) {
        model?.receiveHeartRate(heartRate.beatsPerMinute, at: Date(timeIntervalSince1970: heartRate.measuredAt))
    }

    /// Liveness update during capture. It carries no tap or new coaching line.
    func heartbeat() {
        guard var current = lastSent, current.stage == .capturing else { return }
        current.haptic = .none
        current.sentAt = max(clock(), current.sentAt + 0.001)
        lastSent = current
        deliver(current)
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
        var next = state
        if next.stage == .countdown || next.stage == .capturing, activeSetID == nil {
            activeSetID = UUID().uuidString
        }
        if next.stage == .ready || next.stage == .framing { activeSetID = nil }
        next.setID = activeSetID
        next.languageCode = WatchLanguage.resolved(Bundle.main.preferredLocalizations.first)
        if let lastSent, WatchSyncRules.sameScreen(lastSent, next) { return }
        next.haptic = .none
        next.sentAt = max(clock(), (lastSent?.sentAt ?? 0) + 0.001)
        lastSent = next
        deliver(next)
        if next.stage == .capturing, heartbeatTask == nil {
            heartbeatTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    self?.heartbeat()
                }
            }
        } else if next.stage != .capturing {
            heartbeatTask?.cancel()
            heartbeatTask = nil
        }
    }

    private static func state(of model: WorkoutSessionModel, demoInput: Bool) -> WatchState {
        let exercise: ExerciseKind
        switch model.stage {
        case .ready, .openingCamera, .error: exercise = model.selectedExercise
        case .result: exercise = model.resultExercise
        case .framing, .countdown, .capturing, .analyzing: exercise = model.captureExercise
        }
        var state = WatchSyncRules.state(stage: model.stage, exercise: exercise, liveReps: model.liveRepCount,
                                    caption: model.liveCaption, result: model.result,
                                    cueDismissed: model.cueDismissed, handsFree: model.handsFree,
                                    demoInput: demoInput, measuresHeartRate: false,
                                    coachMessage: model.liveCoachMessage)
        state.hapticsEnabled = model.hapticFeedback != .off
        return state
    }
}
