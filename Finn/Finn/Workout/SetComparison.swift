import Foundation

nonisolated enum RangeDirection: String, Codable, Equatable {
    case longer
    case shorter
    case noClearChange
}

nonisolated struct Comparison: Codable, Equatable {
    let firstSetID: UUID
    let secondSetID: UUID
    let firstMedianRange: Double
    let secondMedianRange: Double
    let firstMedianDuration: TimeInterval
    let secondMedianDuration: TimeInterval
    let rangeDirection: RangeDirection
    let cueRepNumbers: [Int]
    let cueKind: CueKind?
    /// Both sets share this exercise; ranges use its unit.
    let exercise: ExerciseKind

    init(firstSetID: UUID, secondSetID: UUID, firstMedianRange: Double, secondMedianRange: Double,
         firstMedianDuration: TimeInterval, secondMedianDuration: TimeInterval,
         rangeDirection: RangeDirection, cueRepNumbers: [Int], cueKind: CueKind?,
         exercise: ExerciseKind = .bodyweightSquat) {
        self.firstSetID = firstSetID
        self.secondSetID = secondSetID
        self.firstMedianRange = firstMedianRange
        self.secondMedianRange = secondMedianRange
        self.firstMedianDuration = firstMedianDuration
        self.secondMedianDuration = secondMedianDuration
        self.rangeDirection = rangeDirection
        self.cueRepNumbers = cueRepNumbers
        self.cueKind = cueKind
        self.exercise = exercise
    }
}

nonisolated enum SetComparison {
    /// Each set needs this many measured reps for its median to mean something.
    static let minimumReps = 4

    static func compare(_ first: SetSummary, _ second: SetSummary) -> Comparison? {
        guard first.sessionID == second.sessionID,
              first.id != second.id,
              first.exercise == second.exercise,
              first.cameraView == second.cameraView,
// the side is a key only for an exercise measured from the side; a push-up, accepted
              // from any view, compares across sides (filmed from the front, the side is arbitrary).
              first.bodySide == second.bodySide || first.exercise.definition.expectedView != .side,
              first.analysis.rubricVersion == second.analysis.rubricVersion,
              first.analysis.confidence >= EvidenceRubric.minimumJointConfidence,
              second.analysis.confidence >= EvidenceRubric.minimumJointConfidence,
              first.analysis.reps.count >= minimumReps,
              second.analysis.reps.count >= minimumReps else { return nil }

        let firstRange = median(first.analysis.reps.map(\.relativeRange))
        let secondRange = median(second.analysis.reps.map(\.relativeRange))
        guard firstRange > 0 else { return nil }
        let ratio = secondRange / firstRange
        let direction: RangeDirection
        if ratio >= 1.15 { direction = .longer }
        else if ratio <= 0.85 { direction = .shorter }
        else { direction = .noClearChange }
        return Comparison(
            firstSetID: first.id,
            secondSetID: second.id,
            firstMedianRange: firstRange,
            secondMedianRange: secondRange,
            firstMedianDuration: median(first.analysis.reps.map(\.duration)),
            secondMedianDuration: median(second.analysis.reps.map(\.duration)),
            rangeDirection: direction,
            cueRepNumbers: second.cue?.repNumbers ?? [],
            cueKind: second.cue?.kind,
            exercise: second.exercise
        )
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}
