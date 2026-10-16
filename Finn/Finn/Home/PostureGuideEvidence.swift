import Foundation

/// saved measurements only. The illustrated movement has no camera data to compare joint by joint.
nonisolated struct PostureGuideEvidence {
    let latest: SetSummary?
    let measurements: [FormMeasurement]
    let flagged: [FormMeasurement]
    let trends: [FormTrendChange]
    let movementIssue: SetIssue?

    static func make(for exercise: ExerciseKind, history: [WorkoutSessionSummary]) -> Self {
        let sets = history.flatMap(\.sets).filter { $0.exercise == exercise }
            .sorted { $0.capturedAt > $1.capturedAt }
        guard let latest = sets.first else {
            return Self(latest: nil, measurements: [], flagged: [], trends: [], movementIssue: nil)
        }
        let measurements = FormTrend.eligibleMeasurements(in: latest)
        let flagged = measurements.filter {
            $0.faulty >= FormCheck.minimumFaultyReps &&
                Double($0.faulty) / Double($0.judged) >= FormCheck.minimumFaultyShare
        }
        let issue: SetIssue? = if
            latest.analysis.confidence >= EvidenceRubric.minimumJointConfidence,
            latest.partlyVisible != true {
            (latest.issues ?? []).first { issue in
                switch issue {
                case .rangeDropped,
                     .postureChanged,
                     .shallowMovements,
                     .outsideTempo,
                     .spedUp:
                    true
                default:
                    false
                }
            }
        } else { nil }
        return Self(
            latest: latest,
            measurements: measurements,
            flagged: flagged,
            trends: FormTrend.compareLatest(to: latest, among: sets.dropFirst()),
            movementIssue: issue
        )
    }
}

nonisolated enum PostureGuideSteps {
    static func forExercise(_ exercise: ExerciseKind) -> [String] {
        switch exercise {
        case .bodyweightSquat:
            [String(localized: "Feet about shoulder-width"), String(localized: "Hips back and down"),
             String(localized: "Chest tall; knees follow toes")]
        case .pushUp:
            [String(localized: "Hands below shoulders"), String(localized: "Head to heels in one line"),
             String(localized: "Bend elbows; press back up")]
        case .staticLunge:
            [String(localized: "Split stance"), String(localized: "Front knee bends toward 90°"),
             String(localized: "Torso upright")]
        case .stiffLegDeadlift:
            [String(localized: "Soft knees"), String(localized: "Push hips back"),
             String(localized: "Long back; stand tall")]
        case .pullUp:
            [String(localized: "Start with straight arms"), String(localized: "Chin above hands"),
             String(localized: "Lower under control")]
        case .muscleUp:
            [String(localized: "Start from a full hang"), String(localized: "Pull chest above bar"),
             String(localized: "Press to straight arms")]
        }
    }
}

nonisolated extension FormCheck {
    /// a short visible target for a measured check; these are guides, not clinical limits
    var guidePoint: String {
        switch self {
        case .pushUpHipsSag,
             .pushUpHipsPike:
            String(localized: "Shoulders, hips and heels aligned")
        case .pushUpDepth:
            String(localized: "Elbows bend toward 90°")
        case .squatChestDrop:
            String(localized: "Chest stays lifted")
        case .squatDepth:
            String(localized: "Thighs move toward level")
        case .lungeTorsoLean:
            String(localized: "Torso stays upright")
        case .lungeFrontKnee:
            String(localized: "Front knee bends toward 90°")
        case .deadliftKneeBend:
            String(localized: "Knees stay softly bent")
        case .deadliftHinge:
            String(localized: "Hips move back into the hinge")
        }
    }
}
