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
    /// Only used to check the chin against the hands on pull-ups.
    case nose
}

nonisolated struct JointPoint: Codable, Equatable {
    let x: Double
    let y: Double
    let confidence: Double
}

/// How the person doing the set was followed in a frame.
nonisolated enum AthleteTracking: String, Codable, Equatable, Sendable {
    /// `joints` are the athlete's; anyone else is in `bystanders` and ignored.
    case tracked
    /// The athlete is not visible in this frame (hidden, out of view, or not yet found).
    case hidden
}

nonisolated struct PoseFrame: Codable, Equatable {
    /// Seconds since the current capture began.
    let time: TimeInterval
    /// People Vision found in the frame, the athlete included.
    let subjectCount: Int
    /// Vision coordinates normalized to the image: x by its width, y by its height, origin at top left.
    /// With `athleteTracking` set, these are the athlete's joints only.
    let joints: [BodyJoint: JointPoint]
    /// Image height divided by width. Joint angles scale y by this so both axes use the same unit.
    let aspectRatio: Double
    /// Vision's 18-point body keypoints (shape [1, 3, 18], flattened) for the optional exercise classifier.
    let keypoints: [Float]?
    /// Degrees between the body's left-right axis and the camera's line of sight, from Vision 3D pose.
    /// 0 is a true side view and 90 faces the camera. Nil when no 3D estimate exists for this frame.
    let profileDeviationDegrees: Double?
    /// Nil for frames from a source that does not follow one person (tests, older recordings);
    /// the evidence gate then refuses sets with someone else in view.
    let athleteTracking: AthleteTracking?
    /// Everyone else Vision found, for drawing them greyed out. Never analyzed.
    let bystanders: [[BodyJoint: JointPoint]]?

    init(time: TimeInterval, subjectCount: Int, joints: [BodyJoint: JointPoint],
         aspectRatio: Double = 1, keypoints: [Float]? = nil, profileDeviationDegrees: Double? = nil,
         athleteTracking: AthleteTracking? = nil, bystanders: [[BodyJoint: JointPoint]]? = nil) {
        self.time = time
        self.subjectCount = subjectCount
        self.joints = joints
        self.aspectRatio = aspectRatio
        self.keypoints = keypoints
        self.profileDeviationDegrees = profileDeviationDegrees
        self.athleteTracking = athleteTracking
        self.bystanders = bystanders
    }

    func retimed(to time: TimeInterval) -> PoseFrame {
        PoseFrame(time: time, subjectCount: subjectCount, joints: joints, aspectRatio: aspectRatio,
                  keypoints: keypoints, profileDeviationDegrees: profileDeviationDegrees,
                  athleteTracking: athleteTracking, bystanders: bystanders)
    }

    /// The athlete's joints are in this frame and can be measured, whoever else is around.
    var athleteVisible: Bool {
        athleteTracking == .tracked || (athleteTracking == nil && subjectCount == 1)
    }
}

nonisolated struct RepMetric: Codable, Equatable {
    let number: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    /// Range of this rep in its exercise's own unit: the squat stores hip travel divided by
    /// standing leg length; angle-based exercises store degrees of bend from the starting position.
    let relativeRange: Double
    /// Optional side-view posture reading at the deepest phase. Its meaning is exercise-specific;
    /// older saved sessions have no reading and must not produce posture advice.
    let postureValue: Double?

    var duration: TimeInterval { endTime - startTime }
    /// The squat's original name for `relativeRange`, kept for existing callers and saved history.
    var normalizedHipTravel: Double { relativeRange }

    init(number: Int, startTime: TimeInterval, endTime: TimeInterval, relativeRange: Double,
         postureValue: Double? = nil) {
        self.number = number
        self.startTime = startTime
        self.endTime = endTime
        self.relativeRange = relativeRange
        self.postureValue = postureValue
    }

    init(number: Int, startTime: TimeInterval, endTime: TimeInterval, normalizedHipTravel: Double,
         postureValue: Double? = nil) {
        self.init(number: number, startTime: startTime, endTime: endTime,
                  relativeRange: normalizedHipTravel, postureValue: postureValue)
    }

    private enum CodingKeys: String, CodingKey {
        case number
        case startTime
        case endTime
        case relativeRange = "normalizedHipTravel"
        case postureValue
    }
}

nonisolated struct SetAnalysis: Codable, Equatable {
    let reps: [RepMetric]
    let confidence: Double
    let rubricVersion: String
}

/// One rep's lowest moment, kept in memory to draw its skeleton on the result.
nonisolated struct RepSnapshot: Equatable {
    let number: Int
    let range: Double
    let frame: PoseFrame
}

/// The deepest and shallowest reps of a measured set, compared within the person's own set
/// rather than against a universal target.
nonisolated struct RepExtremes: Equatable {
    let deepest: RepSnapshot
    let shallowest: RepSnapshot

    static func make(_ analysis: SetAnalysis, frames: [PoseFrame],
                     definition: ExerciseDefinition) -> RepExtremes? {
        guard analysis.reps.count >= 2,
              let deep = analysis.reps.max(by: { $0.relativeRange < $1.relativeRange }),
              let shallow = analysis.reps.min(by: { $0.relativeRange < $1.relativeRange }),
              deep.number != shallow.number,
              let deepFrame = ExerciseAnalyzer.deepestFrame(of: deep, in: frames, as: definition),
              let shallowFrame = ExerciseAnalyzer.deepestFrame(of: shallow, in: frames, as: definition)
        else { return nil }
        return RepExtremes(deepest: RepSnapshot(number: deep.number, range: deep.relativeRange, frame: deepFrame),
                           shallowest: RepSnapshot(number: shallow.number, range: shallow.relativeRange,
                                                   frame: shallowFrame))
    }
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

nonisolated enum CueKind: String, Codable, Sendable {
    case rangeDecreased
    case torsoTiltIncreased
    case hipDropIncreased
    case kneeBendIncreased
    case swingIncreased
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
    case pullUp
    case muscleUp
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
    /// What this set showed (`SetIssue`), for the person's most frequent pattern. Nil in summaries
    /// saved before 13 October 2026.
    let issues: [SetIssue]?

    init(id: UUID, sessionID: UUID, capturedAt: Date, bodySide: BodySide,
         analysis: SetAnalysis, cue: Cue?, cueResponse: CueResponse,
         exercise: ExerciseKind = .bodyweightSquat, cameraView: CameraView = .side,
         issues: [SetIssue]? = nil) {
        self.id = id
        self.sessionID = sessionID
        self.capturedAt = capturedAt
        self.bodySide = bodySide
        self.analysis = analysis
        self.cue = cue
        self.cueResponse = cueResponse
        self.exercise = exercise
        self.cameraView = cameraView
        self.issues = issues
    }
}

nonisolated struct WorkoutSessionSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    var sets: [SetSummary]
    /// The Apple Health workout saved for this session, so it is never saved twice. Nil until then,
    /// and in sessions saved before 13 October 2026 (decoded as absent).
    var fitnessWorkout: FitnessWorkoutRecord? = nil
    /// True while the session can still take sets: saved with every set and cleared when it ends
    /// (Done, Finish session, or the break that starts a new session). After iOS terminates Plumb
    /// without Done, the next launch finds the session still open. Nil once finished, and in
    /// sessions saved by earlier builds, which count as finished.
    var isOpen: Bool? = nil
}

nonisolated extension WorkoutSessionSummary {
    /// The longest break between two sets of one session. Cancel, or the app going to the background
    /// during a set, leaves the session open without Done; a set measured after a longer break starts
    /// a new session, so one session, and its Apple Health workout, never spans hours or days.
    static let longestBreak: TimeInterval = 30 * 60

    /// Whether a set measured at `date` still belongs to this session.
    func continues(at date: Date) -> Bool {
        let latest = sets.map(\.capturedAt).max() ?? startedAt
        return date.timeIntervalSince(latest) <= Self.longestBreak
    }
}
