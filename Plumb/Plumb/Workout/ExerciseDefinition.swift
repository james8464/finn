import Foundation

/// How one per-frame number is read from 2D pose points. Rep phases are detected on this signal.
nonisolated enum MovementSignal: Equatable, Sendable {
    /// Downward travel of `joint` from its starting height, divided by the starting vertical
    /// distance from `joint` to `reference`. The squat uses hip travel over standing leg length.
    case verticalTravel(joint: JointRole, reference: JointRole)
    /// Degrees that the angle at `vertex`, between `from` and `to`, closes from its starting value.
    case jointBend(from: JointRole, vertex: JointRole, to: JointRole)

    var joints: [JointRole] {
        switch self {
        case .verticalTravel(let joint, let reference): [joint, reference]
        case .jointBend(let from, let vertex, let to): [from, vertex, to]
        }
    }
}

/// The camera view a rubric was written for. Other views make its 2D measurements unreliable.
nonisolated enum ExpectedView: String, Equatable, Sendable {
    case side

    /// Framing prompt when Vision 3D pose sees the person from another angle.
    var turnPrompt: String {
        switch self {
        case .side: "Turn your side to the camera"
        }
    }

    /// Retake reason when most 3D estimates during the set disagree with this view.
    var wrongViewMessage: String {
        switch self {
        case .side: "This exercise needs a side view. Turn so your side faces the camera, then try again."
        }
    }
}

nonisolated enum RangeUnit: Equatable, Sendable {
    /// A fraction of a body length seen by the camera, such as hip travel over leg length.
    case bodyLengthFraction
    /// Degrees of joint bend from the starting position.
    case degrees
}

/// Joints that must stay visible on one body side, plus a joint that should stay still in frame
/// (planted feet or hands). Movement of that anchor means the phone or the person moved.
nonisolated struct EvidenceRequirement: Equatable, Sendable {
    let joints: [JointRole]
    let anchor: JointRole

    static let squat = EvidenceRequirement(joints: [.hip, .knee, .ankle], anchor: .ankle)

    func joints(on side: BodySide) -> [BodyJoint] { joints.map { $0.joint(on: side) } }
}

/// The two phases of a rep, expressed as travel away from the starting (top) position.
/// The set must start in the top phase; the first frames set the baseline.
nonisolated struct RepPhases: Equatable, Sendable {
    /// Travel at which the person has left the top phase and a rep may begin.
    let leaveTop: Double
    /// Smallest travel that reaches the bottom phase. Shallower movements are not counted.
    let reachBottom: Double
    /// Drop from the deepest point that marks the way back up.
    let returnFromBottom: Double
    /// Travel at or below which the person is back in the top phase and the rep ends.
    let backAtTop: Double
    let minimumDuration: TimeInterval
    let maximumDuration: TimeInterval
}

/// Every sentence an exercise shows. Squat copy matches the original squat-only build word for word.
nonisolated struct ExerciseCopy: Equatable, Sendable {
    let name: String
    /// Lowercase noun used in shared text, such as "Plumb squat set".
    let shareNoun: String
    let setupTitle: String
    let placementTitle: String
    let placementDetail: String
    let stanceTitle: String
    let stanceDetail: String
    let framingPrompt: String
    let checkingVisibility: String
    let showJoints: String
    let jointsVisible: String
    /// Shown when too few frames carry the joints the signal needs.
    let keepJointsVisible: String
    /// Shown when the tracked body segment is too small to measure.
    let bodyTooSmall: String
    let retakeHint: String
    let noCompleteReps: String
    /// Noun for the measured range in comparisons, such as "range" or "elbow bend".
    let rangeNoun: String
    let moreRange: String
    let lessRange: String
    let observation: String
    let nextAction: String
    let rangeExplanation: String
    /// Rep accessibility description of the range value.
    let rangeAccessibilityName: String
}

/// One exercise rubric as data: what to track, how a rep moves, which view it needs, and what to say.
/// Thresholds are product hypotheses for a within-person comparison, not validated standards.
nonisolated struct ExerciseDefinition: Equatable, Sendable {
    let kind: ExerciseKind
    let rubricVersion: String
    let expectedView: ExpectedView
    let evidence: EvidenceRequirement
    let signal: MovementSignal
    let phases: RepPhases
    let rangeUnit: RangeUnit
    /// Range that fills the rep bar in the result list.
    let rangeDisplayScale: Double
    /// Smallest baseline body length (verticalTravel, in image-height units) or limb segment
    /// (jointBend, in image-width units) that Plumb will measure.
    let minimumBodyScale: Double
    /// Folder name and label used by the optional Create ML exercise classifier.
    let classifierLabel: String
    let copy: ExerciseCopy

    static let all: [ExerciseDefinition] = [.squat, .pushUp, .staticLunge, .stiffLegDeadlift]

    static func definition(for kind: ExerciseKind) -> ExerciseDefinition {
        switch kind {
        case .bodyweightSquat: .squat
        case .pushUp: .pushUp
        case .staticLunge: .staticLunge
        case .stiffLegDeadlift: .stiffLegDeadlift
        }
    }

    static func definition(forClassifierLabel label: String) -> ExerciseDefinition? {
        all.first { $0.classifierLabel == label }
    }

    func formattedRange(_ value: Double) -> String {
        switch rangeUnit {
        case .bodyLengthFraction: value.formatted(.number.precision(.fractionLength(2)))
        case .degrees: value.formatted(.number.precision(.fractionLength(0))) + "°"
        }
    }

    /// A depth in words, such as "hips 11% of leg length down" or "elbow bent 28°".
    func formattedDepth(_ value: Double) -> String {
        switch (rangeUnit, signal) {
        case (.bodyLengthFraction, _):
            return "hips \(Int((value * 100).rounded()))% of your leg length down"
        case (.degrees, .jointBend(_, let vertex, _)):
            return "\(vertex.rawValue) bent \(Int(value.rounded()))°"
        case (.degrees, _):
            return "\(Int(value.rounded()))°"
        }
    }

    func accessibleRange(_ value: Double) -> String {
        switch rangeUnit {
        case .bodyLengthFraction: value.formatted(.number.precision(.fractionLength(2)))
        case .degrees: value.formatted(.number.precision(.fractionLength(0))) + " degrees"
        }
    }
}

nonisolated extension ExerciseKind {
    var definition: ExerciseDefinition { ExerciseDefinition.definition(for: self) }
}

nonisolated extension ExerciseDefinition {
    /// Side-view bodyweight squat. Values come from `SquatRubric` (`squat-side-v3`).
    static let squat = ExerciseDefinition(
        kind: .bodyweightSquat,
        rubricVersion: SquatRubric.version,
        expectedView: .side,
        evidence: .squat,
        signal: .verticalTravel(joint: .hip, reference: .ankle),
        phases: RepPhases(
            leaveTop: SquatRubric.descentThreshold,
            reachBottom: SquatRubric.minimumHipTravel,
            returnFromBottom: SquatRubric.ascentFromPeakThreshold,
            backAtTop: SquatRubric.completionThreshold,
            minimumDuration: SquatRubric.minimumRepDuration,
            maximumDuration: SquatRubric.maximumRepDuration
        ),
        rangeUnit: .bodyLengthFraction,
        rangeDisplayScale: 0.6,
        minimumBodyScale: 0.1,
        classifierLabel: "squat",
        copy: ExerciseCopy(
            name: "Squat",
            shareNoun: "squat",
            setupTitle: "Squat check",
            placementTitle: "Place your iPhone",
            placementDetail: "At hip height, a few steps away.",
            stanceTitle: "Stand sideways",
            stanceDetail: "Keep your whole body in view.",
            framingPrompt: "Stand sideways. Show head to toe.",
            checkingVisibility: "Checking leg visibility",
            showJoints: "Show hip, knee and ankle",
            jointsVisible: "Hip, knee and ankle visible",
            keepJointsVisible: "Keep your hip and ankle visible for the whole set.",
            bodyTooSmall: "Move the phone back so your full body is visible.",
            retakeHint: "Move the phone farther back and keep your hip, knee, and ankle visible.",
            noCompleteReps: "No complete squat repetitions were measured. Try another set with your full body in view.",
            rangeNoun: "range",
            moreRange: "longer",
            lessRange: "shorter",
            observation: "Your range became shorter in the last two reps.",
            nextAction: "Try a pace you can keep consistent.",
            rangeExplanation: "Relative range compares hip travel with the leg length seen by the camera. Use it only to compare your own sets from the same view.",
            rangeAccessibilityName: "relative camera-observed range"
        )
    )

    /// Side-view push-up, measured as elbow bend (shoulder, elbow, wrist). Hands stay planted.
    static let pushUp = ExerciseDefinition(
        kind: .pushUp,
        rubricVersion: "push-up-side-v2",
        expectedView: .side,
        evidence: EvidenceRequirement(joints: [.shoulder, .elbow, .wrist], anchor: .wrist),
        signal: .jointBend(from: .shoulder, vertex: .elbow, to: .wrist),
        phases: RepPhases(leaveTop: 25, reachBottom: 40, returnFromBottom: 10, backAtTop: 15,
                          minimumDuration: 0.4, maximumDuration: 8.0),
        rangeUnit: .degrees,
        rangeDisplayScale: 120,
        minimumBodyScale: 0.03,
        classifierLabel: "push_up",
        copy: ExerciseCopy(
            name: "Push-up",
            shareNoun: "push-up",
            setupTitle: "Push-up check",
            placementTitle: "Place your iPhone low",
            placementDetail: "On the floor or a low step, a few steps away.",
            stanceTitle: "Turn sideways",
            stanceDetail: "Start at the top, with your arms straight.",
            framingPrompt: "Turn sideways. Keep your whole body in view.",
            checkingVisibility: "Checking arm visibility",
            showJoints: "Show shoulder, elbow and wrist",
            jointsVisible: "Shoulder, elbow and wrist visible",
            keepJointsVisible: "Keep your shoulder, elbow and wrist visible for the whole set.",
            bodyTooSmall: "Plumb couldn’t measure your elbow angle. Keep your side to the camera and move the phone a little closer.",
            retakeHint: "Keep your side to the camera, with your shoulder, elbow, and wrist visible.",
            noCompleteReps: "No complete push-up repetitions were measured. Start at the top with your arms straight and keep your whole body in view.",
            rangeNoun: "elbow bend",
            moreRange: "greater",
            lessRange: "smaller",
            observation: "Your elbow bend became smaller in the last two reps.",
            nextAction: "Try a pace you can keep consistent.",
            rangeExplanation: "Elbow bend is how much your elbow angle closed from the starting position, as seen by the camera. Use it only to compare your own sets from the same view.",
            rangeAccessibilityName: "camera-observed elbow bend"
        )
    )

    /// Side-view static lunge (split squat): feet stay planted, measured as knee bend on the
    /// camera-facing leg (hip, knee, ankle).
    static let staticLunge = ExerciseDefinition(
        kind: .staticLunge,
        rubricVersion: "static-lunge-side-v2",
        expectedView: .side,
        evidence: EvidenceRequirement(joints: [.hip, .knee, .ankle], anchor: .ankle),
        signal: .jointBend(from: .hip, vertex: .knee, to: .ankle),
        phases: RepPhases(leaveTop: 20, reachBottom: 35, returnFromBottom: 10, backAtTop: 15,
                          minimumDuration: 0.5, maximumDuration: 8.0),
        rangeUnit: .degrees,
        rangeDisplayScale: 120,
        minimumBodyScale: 0.03,
        classifierLabel: "static_lunge",
        copy: ExerciseCopy(
            name: "Static lunge",
            shareNoun: "lunge",
            setupTitle: "Lunge check",
            placementTitle: "Place your iPhone",
            placementDetail: "At hip height, a few steps away.",
            stanceTitle: "Stand sideways in a split stance",
            stanceDetail: "Keep both feet planted and the same front leg for each set.",
            framingPrompt: "Stand sideways. Show head to toe.",
            checkingVisibility: "Checking leg visibility",
            showJoints: "Show hip, knee and ankle",
            jointsVisible: "Hip, knee and ankle visible",
            keepJointsVisible: "Keep your hip, knee and ankle visible for the whole set.",
            bodyTooSmall: "Plumb couldn’t measure your knee angle. Keep your side to the camera and your whole body in view.",
            retakeHint: "Move the phone farther back and keep your hip, knee, and ankle visible.",
            noCompleteReps: "No complete lunge repetitions were measured. Start standing tall in your split stance and keep your whole body in view.",
            rangeNoun: "knee bend",
            moreRange: "greater",
            lessRange: "smaller",
            observation: "Your knee bend became smaller in the last two reps.",
            nextAction: "Try a pace you can keep consistent.",
            rangeExplanation: "Knee bend is how much the knee angle on the side facing the camera closed from the starting position. Use it only to compare your own sets from the same view and front leg.",
            rangeAccessibilityName: "camera-observed knee bend"
        )
    )

    /// Side-view stiff-leg deadlift, measured as hip hinge (shoulder, hip, knee). Feet stay planted.
    static let stiffLegDeadlift = ExerciseDefinition(
        kind: .stiffLegDeadlift,
        rubricVersion: "stiff-leg-deadlift-side-v2",
        expectedView: .side,
        evidence: EvidenceRequirement(joints: [.shoulder, .hip, .knee, .ankle], anchor: .ankle),
        signal: .jointBend(from: .shoulder, vertex: .hip, to: .knee),
        phases: RepPhases(leaveTop: 20, reachBottom: 35, returnFromBottom: 10, backAtTop: 15,
                          minimumDuration: 0.6, maximumDuration: 10.0),
        rangeUnit: .degrees,
        rangeDisplayScale: 120,
        minimumBodyScale: 0.03,
        classifierLabel: "stiff_leg_deadlift",
        copy: ExerciseCopy(
            name: "Stiff-leg deadlift",
            shareNoun: "stiff-leg deadlift",
            setupTitle: "Deadlift check",
            placementTitle: "Place your iPhone",
            placementDetail: "At hip height, a few steps away.",
            stanceTitle: "Stand sideways",
            stanceDetail: "Start standing tall, with your whole body in view.",
            framingPrompt: "Stand sideways. Show head to toe.",
            checkingVisibility: "Checking body visibility",
            showJoints: "Show shoulder, hip, knee and ankle",
            jointsVisible: "Shoulder, hip, knee and ankle visible",
            keepJointsVisible: "Keep your shoulder, hip and knee visible for the whole set.",
            bodyTooSmall: "Plumb couldn’t measure your hip angle. Keep your side to the camera and your whole body in view.",
            retakeHint: "Move the phone farther back and keep your shoulder, hip, knee, and ankle visible.",
            noCompleteReps: "No complete stiff-leg deadlift repetitions were measured. Start standing tall and keep your whole body in view.",
            rangeNoun: "hip hinge",
            moreRange: "greater",
            lessRange: "smaller",
            observation: "Your hip hinge became smaller in the last two reps.",
            nextAction: "Try a pace you can keep consistent.",
            rangeExplanation: "Hip hinge is how much the angle between your torso and thigh closed from the starting position, as seen by the camera. Use it only to compare your own sets from the same view.",
            rangeAccessibilityName: "camera-observed hip hinge"
        )
    )
}
