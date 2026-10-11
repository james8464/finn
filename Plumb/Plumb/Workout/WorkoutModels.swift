import Foundation

nonisolated enum BodyJoint: String, Codable, Hashable {
    case leftHip
    case leftKnee
    case leftAnkle
    case rightHip
    case rightKnee
    case rightAnkle
}

nonisolated struct JointPoint: Codable, Equatable {
    let x: Double
    let y: Double
    let confidence: Double
}

nonisolated struct PoseFrame: Codable, Equatable {
    /// Seconds since the current capture began.
    let time: TimeInterval
    let subjectCount: Int
    let joints: [BodyJoint: JointPoint]
}

nonisolated struct RepMetric: Codable, Equatable {
    let number: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let normalizedHipTravel: Double

    var duration: TimeInterval { endTime - startTime }
}

nonisolated struct SetAnalysis: Codable, Equatable {
    let reps: [RepMetric]
    let confidence: Double
    let rubricVersion: String
}

nonisolated enum AnalysisOutcome: Equatable {
    case analyzed(SetAnalysis)
    case insufficientView(String)
    case failed(String)
}

nonisolated enum BodySide: String, Codable {
    case left
    case right
}

nonisolated enum EvidenceReason: String, Codable {
    case tooShort
    case missingJoints
    case lowConfidence
    case multiplePeople
    case unstableFraming
}

nonisolated enum EvidenceAssessment: Equatable {
    case usable(BodySide)
    case reject(EvidenceReason)

    var isRejected: Bool {
        if case .reject = self { return true }
        return false
    }
}

nonisolated enum CueKind: String, Codable {
    case rangeDecreased
}

nonisolated struct Cue: Codable, Equatable {
    let kind: CueKind
    let repNumbers: [Int]
    let earlierMedian: Double
    let laterMedian: Double
    let observation: String
    let nextAction: String
}
