import Foundation

nonisolated enum SetShareSummary {
    static func text(
        for analysis: SetAnalysis,
        cue: Cue?,
        cueDismissed: Bool,
        comparison: Comparison? = nil,
        exercise: ExerciseKind = .bodyweightSquat
    ) -> String {
        let copy = exercise.definition.copy
        let count = analysis.reps.count
        var lines = [
            comparison == nil ? String(localized: "Finn \(copy.shareNoun) set") :
                String(localized: "Finn \(copy.shareNoun) sets"),
            comparison == nil ? String(localized: "\(count) measured reps") :
                String(localized: "Latest set: \(count) measured reps")
        ]
        if cueDismissed {
            lines.append(String(localized: "No observation shared."))
        } else if let cue {
            lines.append(String(localized: "Observation: \(cue.observation)"))
            lines.append(String(localized: "Try next: \(cue.nextAction)"))
        } else {
            lines.append(String(localized: "No clear observation in this set."))
        }
        if let comparison {
            lines
                .append(
                    String(
                        localized: "Compared with the previous set: \(statement(for: comparison.rangeDirection, exercise: exercise))"
                    )
                )
            lines
                .append(
                    String(
                        localized: "This comparison describes one camera-visible measure, not overall technique or safety."
                    )
                )
        }
        lines
            .append(String(localized: "Measured from one side camera view; not a full technique assessment."))
        lines.append(String(localized: "No video is included."))
        return lines.joined(separator: "\n")
    }

    /// The deterministic comparison sentence shown on screen and shared.
    static func statement(for direction: RangeDirection, exercise: ExerciseKind) -> String {
        let copy = exercise.definition.copy
        switch direction {
        case .longer:
            return String(
                localized: "Camera-measured \(copy.rangeNoun) was \(copy.moreRange) in set 2."
            )
        case .shorter:
            return String(
                localized: "Camera-measured \(copy.rangeNoun) was \(copy.lessRange) in set 2."
            )
        case .noClearChange:
            return String(
                localized: "No clear measured \(copy.rangeNoun) change between sets."
            )
        }
    }
}
