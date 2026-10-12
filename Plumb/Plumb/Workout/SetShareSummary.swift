import Foundation

nonisolated enum SetShareSummary {
    static func text(for analysis: SetAnalysis, cue: Cue?, cueDismissed: Bool,
                     comparison: Comparison? = nil) -> String {
        let count = analysis.reps.count
        var lines = [
            comparison == nil ? "Plumb squat set" : "Plumb squat sets",
            "\(comparison == nil ? "" : "Latest set: ")\(count) measured \(count == 1 ? "rep" : "reps")"
        ]
        if cueDismissed {
            lines.append("No observation shared.")
        } else if let cue {
            lines.append("Observation: \(cue.observation)")
            lines.append("Try next: \(cue.nextAction)")
        } else {
            lines.append("No clear observation in this set.")
        }
        if let comparison {
            let statement: String
            switch comparison.rangeDirection {
            case .longer: statement = "Camera-measured range was longer in set 2."
            case .shorter: statement = "Camera-measured range was shorter in set 2."
            case .noClearChange: statement = "No clear measured range change between sets."
            }
            lines.append("Compared with the previous set: \(statement)")
            lines.append("This comparison describes one camera-visible measure, not overall technique or safety.")
        }
        lines.append("Measured from one side camera view; not a full technique assessment.")
        lines.append("No video is included.")
        return lines.joined(separator: "\n")
    }
}
