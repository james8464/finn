import Foundation

/// Short wrist lines from facts the camera has already measured. A language model does not infer
/// form from raw frames here: only LiveSetMonitor's accepted events can trigger technique advice.
nonisolated enum WatchCoachRules {
    static func line(
        for event: LiveSetEvent,
        reps: [RepMetric],
        definition: ExerciseDefinition,
        canCompareRange: Bool = false
    ) -> String? {
        switch event {
        case .fasterThanFirstReps(let rep):
            return String(
                localized: "Rep \(rep) was quicker than your first ones. Give the next one a little more time."
            )
        case .shorterThanFirstReps(let rep):
            return String(
                localized: "Rep \(rep) was shorter than your first ones. Reach the range you started with."
            )
        case .formFault(let check, let rep):
            return String(localized: "Rep \(rep): \(check.liveCue) on the next one. You’ve got this.")
        case .repCountRevised:
            return nil
        case .repCounted(let count):
            guard count == 3 || count == 5 || count == 8 || (count > 8 && count.isMultiple(of: 4))
            else {
                return nil
            }
            if count >= 5, canCompareRange, lastThreeAreConsistent(reps) {
                switch count % 3 {
                case 0:
                    return String(
                        localized: "Rep \(count): your last three held a steady pace. Keep that going."
                    )
                case 1:
                    return String(localized: "Rep \(count): you kept the same range. Stay with it.")
                default:
                    return String(
                        localized: "Rep \(count): those last three stayed steady. Take the next one the same way."
                    )
                }
            }
            switch count {
            case 3:
                return String(localized: "Three reps counted. Find a rhythm you can repeat.")
            case 5:
                return String(localized: "Five reps counted. Stay with me for the next one.")
            case 8:
                return String(localized: "Eight reps in. One at a time—you’ve got this.")
            default:
                return String(localized: "That’s \(count) reps. Keep your next one deliberate.")
            }
        }
    }

    private static func lastThreeAreConsistent(_ reps: [RepMetric]) -> Bool {
        guard reps.count >= 3 else {
            return false
        }
        let last = reps.suffix(3)
        let durations = last.map(\.duration)
        let ranges = last.map(\.relativeRange)
        guard
            let shortest = durations.min(), let longest = durations.max(), shortest > 0,
            let smallestRange = ranges.min(), let largestRange = ranges.max(),
            largestRange > 0 else {
            return false
        }
        return longest / shortest <= 1.2 && smallestRange / largestRange >= 0.85
    }
}
