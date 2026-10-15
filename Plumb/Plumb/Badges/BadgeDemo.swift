import Foundation

#if DEBUG
/// A few earned badges for screenshots of the Awards screen (`-plumb-ui-badges-demo`). Demo input only.
enum BadgeDemo {
    static var sample: [EarnedBadge] {
        let now = Date()
        return [
            EarnedBadge(kind: .firstSet, earnedAt: now.addingTimeInterval(-9 * 86_400),
                        detail: "6 squat reps, measured on this iPhone."),
            EarnedBadge(kind: .repRecord(.bodyweightSquat), earnedAt: now.addingTimeInterval(-6 * 86_400),
                        detail: "9 squat reps, up from 6 in your best earlier set."),
            EarnedBadge(kind: .threeDaysInAWeek, earnedAt: now.addingTimeInterval(-2 * 86_400),
                        detail: "Sets on Monday, Wednesday and Friday, within seven days."),
            EarnedBadge(kind: .cleanSet, earnedAt: now.addingTimeInterval(-3_600),
                        detail: "8 push-up reps, every joint clear, no pattern to correct."),
        ]
    }
}
#endif
