import Foundation

enum BodyJoint: String, Codable, Hashable {
    case leftHip
    case leftKnee
    case leftAnkle
    case rightHip
    case rightKnee
    case rightAnkle
}

struct JointPoint: Codable, Equatable {
    let x: Double
    let y: Double
    let confidence: Double
}

struct PoseFrame: Codable, Equatable {
    /// Seconds since the current capture began.
    let time: TimeInterval
    let subjectCount: Int
    let joints: [BodyJoint: JointPoint]
}

struct RepMetric: Codable, Equatable {
    let number: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let normalizedHipTravel: Double

    var duration: TimeInterval { endTime - startTime }
}

struct SetAnalysis: Codable, Equatable {
    let reps: [RepMetric]
    let confidence: Double
    let rubricVersion: String
}

enum AnalysisOutcome: Equatable {
    case analyzed(SetAnalysis)
    case insufficientView(String)
    case failed(String)
}
