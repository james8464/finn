import ActivityKit
import Foundation

/// a set in progress, on the Lock Screen and in the Dynamic Island. The app starts it when the set
/// starts, updates the count on each rep, and ends it with the set. Updates are local: no push.
///
/// Compiled into the app and the widget extension
nonisolated struct FinnSetActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// reps counted so far
        var reps: Int
    }

    /// the exercise as the app names it ("Squat", "Push-up")
    let exerciseName: String
    /// when the set started; the activity shows a running clock from here
    let startedAt: Date
    /// demo or recorded input, labelled as such: never presented as live tracking
    let demoInput: Bool
}
