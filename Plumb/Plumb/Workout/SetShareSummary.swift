import Foundation

nonisolated enum SetShareSummary {
    static func text(for analysis: SetAnalysis, cue: Cue?, cueDismissed: Bool,
                     comparison: Comparison? = nil,
                     exercise: ExerciseKind = .bodyweightSquat) -> String {
        let copy = exercise.definition.copy
        let count = analysis.reps.count
        var lines = [
            "Plumb \(copy.shareNoun) \(comparison == nil ? "set" : "sets")",
            "\(comparison == nil ? "" : "Latest set: ")\(count) measured \(count == 1 ? "rep" : "reps")"
        ]
        if cueDismissed {
            lines.append("No observation shared.")
        } else if let cue {
            lines.append("Observation: \(cue.observation)")
            lines.append("Try next: \(cue.nextAction)")
        } else if CueSelector.hasConsistentRange(analysis) {
            lines.append("Observation: \(copy.consistentRangeMessage)")
        } else {
            lines.append("No clear observation in this set.")
        }
        if let comparison {
            lines.append("Compared with the previous set: \(statement(for: comparison.rangeDirection, exercise: exercise))")
            lines.append("This comparison describes one camera-visible measure, not overall technique or safety.")
        }
        lines.append("Measured from one side camera view; not a full technique assessment.")
        lines.append("No video is included.")
        return lines.joined(separator: "\n")
    }

    /// The deterministic comparison sentence shown on screen and shared.
    static func statement(for direction: RangeDirection, exercise: ExerciseKind) -> String {
        let copy = exercise.definition.copy
        switch direction {
        case .longer: return "Camera-measured \(copy.rangeNoun) was \(copy.moreRange) in set 2."
        case .shorter: return "Camera-measured \(copy.rangeNoun) was \(copy.lessRange) in set 2."
        case .noClearChange: return "No clear measured \(copy.rangeNoun) change between sets."
        }
    }
}
