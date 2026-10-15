import Observation

/// what Siri or a shortcut asked the app to do once it is in front. An intent that opens the app
/// runs before the first screen can act, so it leaves its request here and `ContentView` picks it
/// up when the model is ready for it (first screen or result, never during a set).
@Observable
final class SiriLaunchRequests {
    static let shared = SiriLaunchRequests()

    enum Request: Equatable {
        /// "Start a squat set in Plumb": choose the exercise and open the camera.
        case startSet(ExerciseKind)
        /// "Show my history in Plumb".
        case showHistory
    }

    var pending: Request?

    init(pending: Request? = nil) {
        self.pending = pending
    }

    /// whether `request` can be carried out at `stage`: a set in progress is never interrupted by
    /// Siri, and History opens from the first screen only. Pure, so tests cover it.
    nonisolated static func canApply(_ request: Request, at stage: WorkoutStage) -> Bool {
        switch request {
        case .startSet: return stage == .ready || stage == .result
        case .showHistory: return stage == .ready
        }
    }
}
