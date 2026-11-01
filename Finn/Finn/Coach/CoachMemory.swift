import Foundation

/// what Finn always remembers about the person: every onboarding answer, one a line, in the
/// person's own words where they typed them. Rebuilt from the saved answers and sent with every
/// message, so the model rereads it each turn and a changed answer reaches the next reply.
/// Questions left unanswered are left out; nil when nothing was answered
nonisolated extension OnboardingProfile {
    var coachMemory: String? {
        var lines: [String] = []
        if let name = preferredName {
            lines.append("First name: " + name.prefix(40))
        }
        if let goal {
            lines.append("Goal: " + goal.title)
        }
        if let level {
            lines.append("Training level: " + level.title)
        }
        if !favouriteExercises.isEmpty {
            lines.append("Favourite exercises: " + favouriteExercises.map(\.definition.copy.name).joined(separator: ", "))
        }
        if let followedProgram {
            var line = "Has followed a training programme before: " + (followedProgram ? "yes" : "no")
            if followedProgram, !stopReasons.isEmpty {
                line += "; stopped because: " + stopReasons.map(\.title).joined(separator: ", ")
            }
            lines.append(line)
        }
        if let intensity {
            lines.append("How hard Finn should push: " + intensity.title)
        }
        if let days {
            lines.append("Days a week they can train: " + days.title)
        }
        if let sex {
            lines.append("Sex: " + sex.title)
        }
        if let heightCentimeters {
            lines.append("Height: \(heightCentimeters) cm")
        }
        if let weightKilograms {
            lines.append("Weight: " + weightKilograms.formatted(.number.precision(.fractionLength(0 ... 1))) + " kg")
        }
        if let location {
            lines.append("Where they train: " + location.title)
        }
        if !equipment.isEmpty {
            lines.append("Equipment: " + equipment.map(\.title).joined(separator: ", "))
        }
        let injuries = injuries.trimmingCharacters(in: .whitespacesAndNewlines)
        if noPastInjuries {
            lines.append("Past injuries: none")
        } else if !injuries.isEmpty {
            lines.append("Past injuries, in their words: " + injuries.prefix(300).replacing("\n", with: " "))
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
