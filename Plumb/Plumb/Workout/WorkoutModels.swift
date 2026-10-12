import Foundation

nonisolated enum BodyJoint: String, Codable, Hashable {
    case leftHip
    case leftKnee
    case leftAnkle
    case rightHip
    case rightKnee
    case rightAnkle
    case leftShoulder
    case leftElbow
    case leftWrist
    case rightShoulder
    case rightElbow
    case rightWrist
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
    /// Vision coordinates normalized to the image: x by its width, y by its height, origin at top left.
    let joints: [BodyJoint: JointPoint]
    /// Image height divided by width. Joint angles scale y by this so both axes use the same unit.
    let aspectRatio: Double
    /// Vision's 18-point body keypoints (shape [1, 3, 18], flattened) for the optional exercise classifier.
    let keypoints: [Float]?
    /// Degrees between the body's left-right axis and the camera's line of sight, from Vision 3D pose.
    /// 0 is a true side view and 90 faces the camera. Nil when no 3D estimate exists for this frame.
    let profileDeviationDegrees: Double?

    init(time: TimeInterval, subjectCount: Int, joints: [BodyJoint: JointPoint],
         aspectRatio: Double = 1, keypoints: [Float]? = nil, profileDeviationDegrees: Double? = nil) {
        self.time = time
        self.subjectCount = subjectCount
        self.joints = joints
        self.aspectRatio = aspectRatio
        self.keypoints = keypoints
        self.profileDeviationDegrees = profileDeviationDegrees
    }

    func retimed(to time: TimeInterval) -> PoseFrame {
        PoseFrame(time: time, subjectCount: subjectCount, joints: joints, aspectRatio: aspectRatio,
                  keypoints: keypoints, profileDeviationDegrees: profileDeviationDegrees)
    }
}

nonisolated struct RepMetric: Codable, Equatable {
    let number: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    /// Range of this rep in its exercise's own unit: the squat stores hip travel divided by
    /// standing leg length; angle-based exercises store degrees of bend from the starting position.
    let relativeRange: Double

    var duration: TimeInterval { endTime - startTime }
    /// The squat's original name for `relativeRange`, kept for existing callers and saved history.
    var normalizedHipTravel: Double { relativeRange }

    init(number: Int, startTime: TimeInterval, endTime: TimeInterval, relativeRange: Double) {
        self.number = number
        self.startTime = startTime
        self.endTime = endTime
        self.relativeRange = relativeRange
    }

    init(number: Int, startTime: TimeInterval, endTime: TimeInterval, normalizedHipTravel: Double) {
        self.init(number: number, startTime: startTime, endTime: endTime,
                  relativeRange: normalizedHipTravel)
    }

    private enum CodingKeys: String, CodingKey {
        case number
        case startTime
        case endTime
        case relativeRange = "normalizedHipTravel"
    }
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

nonisolated enum BodySide: String, Codable, Equatable {
    case left
    case right
}

/// A joint named without its body side. The evidence gate picks the side the camera tracks best.
nonisolated enum JointRole: String, Equatable, Sendable {
    case shoulder
    case elbow
    case wrist
    case hip
    case knee
    case ankle

    func joint(on side: BodySide) -> BodyJoint {
        switch (self, side) {
        case (.shoulder, .left): .leftShoulder
        case (.shoulder, .right): .rightShoulder
        case (.elbow, .left): .leftElbow
        case (.elbow, .right): .rightElbow
        case (.wrist, .left): .leftWrist
        case (.wrist, .right): .rightWrist
        case (.hip, .left): .leftHip
        case (.hip, .right): .rightHip
        case (.knee, .left): .leftKnee
        case (.knee, .right): .rightKnee
        case (.ankle, .left): .leftAnkle
        case (.ankle, .right): .rightAnkle
        }
    }
}

nonisolated enum EvidenceReason: String, Codable {
    case tooShort
    case missingJoints
    case lowConfidence
    case multiplePeople
    case unstableFraming
    case trackingGap
}

nonisolated enum EvidenceAssessment: Equatable {
    case usable(BodySide)
    case reject(EvidenceReason)

    var isRejected: Bool {
        if case .reject = self { return true }
        return false
    }
}

nonisolated enum FramingStatus: Equatable {
    case checking
    case adjustPosition
    case landmarksVisible
    /// Vision 3D pose sees the person from an angle the exercise does not support.
    case turnToExpectedView
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

nonisolated enum ExerciseKind: String, Codable, Equatable, CaseIterable {
    case bodyweightSquat
    case pushUp
    case staticLunge
    case stiffLegDeadlift
}

nonisolated enum CameraView: String, Codable, Equatable {
    case side
    case front
}

nonisolated enum CueResponse: String, Codable, Equatable {
    case unanswered
    case notRelevant
}

nonisolated struct SetSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let capturedAt: Date
    let bodySide: BodySide
    let analysis: SetAnalysis
    let cue: Cue?
    var cueResponse: CueResponse
    let exercise: ExerciseKind
    let cameraView: CameraView

    init(id: UUID, sessionID: UUID, capturedAt: Date, bodySide: BodySide,
         analysis: SetAnalysis, cue: Cue?, cueResponse: CueResponse,
         exercise: ExerciseKind = .bodyweightSquat, cameraView: CameraView = .side) {
        self.id = id
        self.sessionID = sessionID
        self.capturedAt = capturedAt
        self.bodySide = bodySide
        self.analysis = analysis
        self.cue = cue
        self.cueResponse = cueResponse
        self.exercise = exercise
        self.cameraView = cameraView
    }
}

nonisolated struct WorkoutSessionSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    var sets: [SetSummary]
}
