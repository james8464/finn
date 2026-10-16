import Foundation

nonisolated enum CueSelector {
    /// At most one observation. Prefer a supported posture change when rep range is comparable;
    /// otherwise retain the existing within-set range observation.
    static func select(from analysis: SetAnalysis,
                       exercise definition: ExerciseDefinition = .squat) -> Cue? {
        guard analysis.confidence >= EvidenceRubric.minimumJointConfidence,
              analysis.reps.count >= 4 else { return nil }

        let ordered = analysis.reps.sorted { $0.number < $1.number }
        let first = Array(ordered.prefix(2))
        let last = Array(ordered.suffix(2))
        let earlierMedian = (first[0].relativeRange + first[1].relativeRange) / 2
        let laterMedian = (last[0].relativeRange + last[1].relativeRange) / 2
        guard earlierMedian > 0 else { return nil }

        if abs(laterMedian / earlierMedian - 1) <= 0.10,
           let firstValues = values(from: first), let lastValues = values(from: last) {
            let earlierPosture = (firstValues[0] + firstValues[1]) / 2
            let laterPosture = (lastValues[0] + lastValues[1]) / 2
            let rule = definition.posture
            if lastValues.allSatisfy({ $0 - earlierPosture >= rule.minimumIncrease }) {
                return Cue(kind: rule.cueKind, repNumbers: last.map(\.number),
                           earlierMedian: earlierPosture, laterMedian: laterPosture,
                           observation: rule.observation, nextAction: rule.nextAction)
            }
        }

        guard laterMedian <= earlierMedian * 0.85 else { return nil }

        return Cue(
            kind: .rangeDecreased,
            repNumbers: last.map(\.number),
            earlierMedian: earlierMedian,
            laterMedian: laterMedian,
            observation: definition.copy.observation,
            nextAction: definition.copy.nextAction
        )
    }

    private static func values(from reps: [RepMetric]) -> [Double]? {
        let result = reps.compactMap(\.postureValue)
        return result.count == reps.count ? result : nil
    }
}
