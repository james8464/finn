import Foundation

nonisolated enum SetShareSummary {
    static func text(for analysis: SetAnalysis, cue: Cue?, cueDismissed: Bool) -> String {
        let count = analysis.reps.count
        var lines = [
            "Plumb squat set",
            "\(count) measured \(count == 1 ? "rep" : "reps")"
        ]
        if cueDismissed {
            lines.append("No observation shared.")
        } else if let cue {
            lines.append("Observation: \(cue.observation)")
            lines.append("Try next: \(cue.nextAction)")
        } else {
            lines.append("No clear observation in this set.")
        }
        lines.append("Measured from one side camera view; not a full technique assessment.")
        lines.append("No video is included.")
        return lines.joined(separator: "\n")
    }
}
