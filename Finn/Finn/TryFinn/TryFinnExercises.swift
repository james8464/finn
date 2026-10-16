import Foundation

/// the three levels Try Finn knows. Read from the training level saved by the onboarding
nonisolated enum TryFinnLevel: String, CaseIterable, Sendable {
    case beginner, intermediate, advanced

    /// matched on the saved value rather than the enum's cases, so this keeps compiling while the
    /// onboarding adds levels. "returning", an unknown value or no answer at all start as beginner
    init(_ level: TrainingLevel?) {
        switch level?.rawValue {
        case "regular": self = .intermediate
        case "experienced": self = .advanced
        default: self = .beginner
        }
    }
}

/// the first exercise a new person tries, and how many reps end it. Edit `forLevel` to change
/// either; the name, the drawing and the form steps come from the exercise itself, the same ones
/// Posture shows
nonisolated struct TryFinnExercise: Equatable, Sendable {
    let level: TryFinnLevel
    let kind: ExerciseKind
    /// the set ends by itself once Finn has counted these
    let reps: Int

    static func forLevel(_ level: TryFinnLevel) -> TryFinnExercise {
        switch level {
        case .beginner: TryFinnExercise(level: level, kind: .bodyweightSquat, reps: 8)
        case .intermediate: TryFinnExercise(level: level, kind: .staticLunge, reps: 10)
        case .advanced: TryFinnExercise(level: level, kind: .pushUp, reps: 12)
        }
    }

    var name: String { kind.definition.copy.name }
    /// how to move well, in three short steps (Posture's "How to move")
    var formSteps: [String] { PostureGuideSteps.forExercise(kind) }
}
