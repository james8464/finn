import Foundation

nonisolated enum CueSelector {
    /// A positive finding about one measured signal, never a judgment of overall technique.
    /// Every counted rep must stay within 12% of the largest range, with clear pose evidence.
    static func hasConsistentRange(_ analysis: SetAnalysis) -> Bool {
        guard analysis.confidence >= 0.8, analysis.reps.count >= 4,
              let smallest = analysis.reps.map(\.relativeRange).min(),
              let largest = analysis.reps.map(\.relativeRange).max(),
              largest > 0 else { return false }
        return smallest / largest >= 0.88
    }

    /// One within-set observation: the last two reps' range against the first two.
    /// The wording comes from the exercise definition; the rule is the same for every exercise.
    static func select(from analysis: SetAnalysis,
                       exercise definition: ExerciseDefinition = .squat) -> Cue? {
        guard analysis.confidence >= EvidenceRubric.minimumJointConfidence,
              analysis.reps.count >= 4 else { return nil }

        let ordered = analysis.reps.sorted { $0.number < $1.number }
        let first = Array(ordered.prefix(2))
        let last = Array(ordered.suffix(2))
        let earlierMedian = (first[0].relativeRange + first[1].relativeRange) / 2
        let laterMedian = (last[0].relativeRange + last[1].relativeRange) / 2
        guard earlierMedian > 0,
              laterMedian <= earlierMedian * 0.85 else { return nil }

        return Cue(
            kind: .rangeDecreased,
            repNumbers: last.map(\.number),
            earlierMedian: earlierMedian,
            laterMedian: laterMedian,
            observation: definition.copy.observation,
            nextAction: definition.copy.nextAction
        )
    }
}
