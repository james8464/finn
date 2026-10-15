import AppIntents

/// the six exercises as a Siri parameter: "Start a push-up set in Finn". One case per
/// `ExerciseKind`, with the names and synonyms Siri listens for
nonisolated enum ExerciseChoice: String, AppEnum {
    case squat
    case pushUp
    case lunge
    case stiffLegDeadlift
    case pullUp
    case muscleUp

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exercise")

    static let caseDisplayRepresentations: [ExerciseChoice: DisplayRepresentation] = [
        .squat: DisplayRepresentation(title: "Squat",
                                      synonyms: ["squats", "bodyweight squat", "air squat"]),
        .pushUp: DisplayRepresentation(title: "Push-up",
                                       synonyms: ["push-ups", "pushup", "pushups", "press-up"]),
        .lunge: DisplayRepresentation(title: "Lunge",
                                      synonyms: ["lunges", "static lunge", "split squat"]),
        .stiffLegDeadlift: DisplayRepresentation(title: "Stiff-leg deadlift",
                                                 synonyms: ["deadlift", "deadlifts", "straight-leg deadlift",
                                                            "Romanian deadlift"]),
        .pullUp: DisplayRepresentation(title: "Pull-up",
                                       synonyms: ["pull-ups", "pullup", "pullups", "chin-up"]),
        .muscleUp: DisplayRepresentation(title: "Muscle-up",
                                         synonyms: ["muscle-ups", "muscleup", "bar muscle-up"])
    ]

    /// the app's exercise behind this choice
    var kind: ExerciseKind {
        switch self {
        case .squat: .bodyweightSquat
        case .pushUp: .pushUp
        case .lunge: .staticLunge
        case .stiffLegDeadlift: .stiffLegDeadlift
        case .pullUp: .pullUp
        case .muscleUp: .muscleUp
        }
    }

    init(_ kind: ExerciseKind) {
        switch kind {
        case .bodyweightSquat: self = .squat
        case .pushUp: self = .pushUp
        case .staticLunge: self = .lunge
        case .stiffLegDeadlift: self = .stiffLegDeadlift
        case .pullUp: self = .pullUp
        case .muscleUp: self = .muscleUp
        }
    }
}
