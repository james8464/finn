import ActivityKit
import Foundation

/// A set in progress, on the Lock Screen and in the Dynamic Island. The app starts it when the set
/// starts, updates the count on each rep, and ends it with the set. Updates are local: no push.
///
/// Compiled into the app and the widget extension.
nonisolated struct FinnSetActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Reps counted so far.
        var reps: Int
    }

    /// The exercise as the app names it ("Squat", "Push-up").
    let exerciseName: String
    /// When the set started; the activity shows a running clock from here.
    let startedAt: Date
    /// Demo or recorded input, labeled as such: never presented as live tracking.
    let demoInput: Bool
}
