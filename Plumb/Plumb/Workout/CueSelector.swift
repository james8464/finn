import Foundation

nonisolated enum CueSelector {
    static func select(from analysis: SetAnalysis) -> Cue? {
        guard analysis.confidence >= SquatRubric.minimumJointConfidence,
              analysis.reps.count >= 4 else { return nil }

        let ordered = analysis.reps.sorted { $0.number < $1.number }
        let first = Array(ordered.prefix(2))
        let last = Array(ordered.suffix(2))
        let earlierMedian = (first[0].normalizedHipTravel + first[1].normalizedHipTravel) / 2
        let laterMedian = (last[0].normalizedHipTravel + last[1].normalizedHipTravel) / 2
        guard earlierMedian > 0,
              laterMedian <= earlierMedian * 0.85 else { return nil }

        return Cue(
            kind: .rangeDecreased,
            repNumbers: last.map(\.number),
            earlierMedian: earlierMedian,
            laterMedian: laterMedian,
            observation: "Your range became shorter in the last two reps.",
            nextAction: "Try a pace you can keep consistent."
        )
    }
}
