import Foundation

/// How one per-frame number is read from 2D pose points. Rep phases are detected on this signal.
nonisolated enum MovementSignal: Equatable, Sendable {
    /// Downward travel of `joint` from its starting height, divided by the starting vertical
    /// distance from `joint` to `reference`. The squat uses hip travel over standing leg length.
    case verticalTravel(joint: JointRole, reference: JointRole)
    /// Degrees that the angle at `vertex`, between `from` and `to`, closes from its starting value.
    case jointBend(from: JointRole, vertex: JointRole, to: JointRole)
    /// Upward travel of `joint` from its lowest position, divided by its largest distance below
    /// `reference`. Pull-ups use shoulder rise over arm length, with the hands on the bar.
    case verticalRise(joint: JointRole, reference: JointRole)
    /// Downward travel of the trunk from its highest position. Push-ups whose elbows and wrists the
    /// side-view rubric cannot read follow the shoulders' midpoint, in image widths; squats whose
    /// knees and ankles it cannot read follow the hips, in torso lengths. Both count sets filmed
    /// from the front or with the phone on the floor.
    case shoulderDrop

    var joints: [JointRole] {
        switch self {
        case .verticalTravel(let joint, let reference): [joint, reference]
        case .jointBend(let from, let vertex, let to): [from, vertex, to]
        case .verticalRise(let joint, let reference): [joint, reference]
        case .shoulderDrop: [.shoulder]
        }
    }
}

/// The camera view a rubric was written for. Other views make its 2D measurements unreliable.
nonisolated enum ExpectedView: String, Equatable, Sendable {
    case side
    /// Pull-ups and muscle-ups: the shoulders' rise towards the hands reads the same from the
    /// side, the front or the back, so the 3D check never asks to turn.
    case any

    /// Framing prompt when Vision 3D pose sees the person from another angle.
    var turnPrompt: String {
        switch self {
        case .side: String(localized: "Turn a little: side to the camera")
        case .any: ""
        }
    }

    /// Retake reason when the 3D estimates show the person clearly facing the camera for several seconds.
    var wrongViewMessage: String {
        switch self {
        case .side: String(localized: "This exercise needs a side view. Turn so your side faces the camera, then try again.")
        case .any: ""
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
    /// Lowercase noun used in shared text, such as "Finn squat set".
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
    /// Shown and said during a set when a rep's range is clearly shorter than the first reps. An
    /// order of two or three words that is understood mid-effort ("Go lower"), never a description
    /// of the measurement ("Elbow bend is smaller", which told the athlete nothing to do, 15 October).
    let liveShorterCue: String
    let observation: String
    let nextAction: String
    let rangeExplanation: String
    /// Rep accessibility description of the range value.
    let rangeAccessibilityName: String

}

/// A within-person posture change, not an absolute standard of correct technique.
nonisolated struct PostureRule: Equatable, Sendable {
    let cueKind: CueKind
    let minimumIncrease: Double
    let observation: String
    let nextAction: String

    /// The change in a few words, for the most-frequent-pattern summary.
    var title: String {
        switch cueKind {
        case .torsoTiltIncreased: "Torso tilting farther at the end of the set"
        case .hipDropIncreased: "Hips sagging at the end of the set"
        case .kneeBendIncreased: "Knees bending more at the end of the set"
        case .swingIncreased: "Body swinging more at the end of the set"
        case .rangeDecreased: "Range shorter at the end of the set"
        case .pushUpHipsSag, .pushUpHipsPike, .pushUpDepth, .squatChestDrop, .squatDepth, .lungeTorsoLean,
             .lungeFrontKnee, .deadliftKneeBend, .deadliftHinge:
            FormCheck(cueKind: cueKind)?.title ?? ""
        }
    }
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
    /// (jointBend, in image-width units) that Finn will measure.
    let minimumBodyScale: Double
    /// Folder name and label used by the optional Create ML exercise classifier.
    let classifierLabel: String
    let posture: PostureRule
    let copy: ExerciseCopy

    static let all: [ExerciseDefinition] = [.squat, .pushUp, .staticLunge, .stiffLegDeadlift, .pullUp, .muscleUp]

    static func definition(for kind: ExerciseKind) -> ExerciseDefinition {
        switch kind {
        case .bodyweightSquat: .squat
        case .pushUp: .pushUp
        case .staticLunge: .staticLunge
        case .stiffLegDeadlift: .stiffLegDeadlift
        case .pullUp: .pullUp
        case .muscleUp: .muscleUp
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
        case (_, .shoulderDrop) where kind == .bodyweightSquat:
            return "hips \(Int((value * 100).rounded()))% of your torso length down"
        case (_, .shoulderDrop):
            return String(localized: "shoulders \(Int((value * 100).rounded()))% of the picture width down")
        case (.bodyLengthFraction, .verticalRise):
            return String(localized: "shoulders up \(Int((value * 100).rounded()))% of your arm length")
        case (.bodyLengthFraction, _):
            return String(localized: "hips \(Int((value * 100).rounded()))% of your leg length down")
        case (.degrees, .jointBend(_, let vertex, _)):
            let degrees = Int(value.rounded())
            switch vertex {
            case .elbow: return String(localized: "elbow bent \(degrees)°")
            case .knee: return String(localized: "knee bent \(degrees)°")
            case .hip: return String(localized: "hip bent \(degrees)°")
            default: return "\(vertex.rawValue) bent \(degrees)°"
            }
        case (.degrees, _):
            return "\(Int(value.rounded()))°"
        }
    }

    func accessibleRange(_ value: Double) -> String {
        switch rangeUnit {
        case .bodyLengthFraction: value.formatted(.number.precision(.fractionLength(2)))
        case .degrees: value.formatted(.number.precision(.fractionLength(0))) + String(localized: " degrees")
        }
    }
}

nonisolated extension ExerciseKind {
    var definition: ExerciseDefinition { ExerciseDefinition.definition(for: self) }
}

nonisolated extension ExerciseDefinition {
    /// Side-view bodyweight squat. Values come from `SquatRubric` (`squat-side-v7`).
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
        posture: PostureRule(
            cueKind: .torsoTiltIncreased, minimumIncrease: 12,
            observation: String(localized: "Your torso tilted farther from upright in the last two reps."),
            nextAction: String(localized: "Try keeping your torso angle similar from rep to rep.")
        ),
        copy: ExerciseCopy(
            name: String(localized: "Squat"),
            shareNoun: String(localized: "squat"),
            setupTitle: String(localized: "Squat check"),
            placementTitle: String(localized: "Place your iPhone"),
            placementDetail: String(localized: "At hip height, a few steps away."),
            stanceTitle: String(localized: "Stand sideways"),
            stanceDetail: String(localized: "Keep your whole body in view."),
            framingPrompt: String(localized: "Stand sideways. Show head to toe."),
            checkingVisibility: String(localized: "Checking leg visibility"),
            showJoints: String(localized: "Show hip, knee and ankle"),
            jointsVisible: String(localized: "Hip, knee and ankle visible"),
            keepJointsVisible: String(localized: "Keep your hip and ankle visible for the whole set."),
            bodyTooSmall: String(localized: "Your legs look too small to measure. Move the phone closer, keeping your whole body in view."),
            retakeHint: String(localized: "Move the phone farther back and keep your hip, knee, and ankle visible."),
            noCompleteReps: String(localized: "No complete squat repetitions were measured. Try another set with your full body in view."),
            rangeNoun: String(localized: "range"),
            moreRange: String(localized: "longer"),
            lessRange: String(localized: "shorter"),
            liveShorterCue: String(localized: "Sit lower"),
            observation: String(localized: "Your range became shorter in the last two reps."),
            nextAction: String(localized: "Choose a range you can repeat on each rep."),
            rangeExplanation: String(localized: "Relative range compares hip travel with the leg length seen by the camera. Use it only to compare your own sets from the same view."),
            rangeAccessibilityName: String(localized: "relative camera-observed range")
        )
    )

    /// The least a push-up may take, from leaving the top to being 65% of the way back up. A rep
    /// is already required to bend the elbow 40° (or drop the shoulders 55% of the set's travel), which
    /// Vision's jitter does not do; the tempo floor only has to reject a flicker. At 0.4 s, 15 of
    /// Guilhem's fast push-ups on 15 October (about 0.65 s a cycle, so under 0.4 s measured this way)
    /// were refused as "faster than 0.4 s" while the live count had said them.
    static let minimumPushUpDuration: TimeInterval = 0.25

    /// Side-view push-up, measured as elbow bend (shoulder, elbow, wrist). Hands stay planted.
    static let pushUp = ExerciseDefinition(
        kind: .pushUp,
        rubricVersion: "push-up-side-v7",
        expectedView: .any,
        evidence: EvidenceRequirement(joints: [.shoulder, .elbow, .wrist], anchor: .wrist),
        signal: .jointBend(from: .shoulder, vertex: .elbow, to: .wrist),
        phases: RepPhases(leaveTop: 25, reachBottom: 40, returnFromBottom: 10, backAtTop: 15,
                          minimumDuration: minimumPushUpDuration, maximumDuration: 8.0),
        rangeUnit: .degrees,
        rangeDisplayScale: 120,
        minimumBodyScale: 0.03,
        classifierLabel: "push_up",
        posture: PostureRule(
            cueKind: .hipDropIncreased, minimumIncrease: 0.06,
            observation: String(localized: "Your hips sat lower relative to your shoulder-to-ankle line in the last two reps."),
            nextAction: String(localized: "Try keeping your hips aligned with your shoulders and ankles.")
        ),
        copy: ExerciseCopy(
            name: String(localized: "Push-up"),
            shareNoun: String(localized: "push-up"),
            setupTitle: String(localized: "Push-up check"),
            placementTitle: String(localized: "Place your iPhone low"),
            placementDetail: String(localized: "On the floor or a low step, a few steps away."),
            stanceTitle: String(localized: "Face the phone or turn sideways"),
            stanceDetail: String(localized: "Front or side both work. Start at the top, with your arms straight."),
            framingPrompt: String(localized: "Face the phone or turn sideways. Keep your upper body and hands in view."),
            checkingVisibility: String(localized: "Checking shoulder and hand visibility"),
            showJoints: String(localized: "Show your shoulders and hands"),
            jointsVisible: String(localized: "Shoulders and hands visible"),
            keepJointsVisible: String(localized: "Keep your shoulders and hands visible for the whole set."),
            bodyTooSmall: String(localized: "Finn couldn’t measure your movement. Keep your shoulders and hands in view and move the phone a little closer."),
            retakeHint: String(localized: "Face the phone or turn sideways, with your shoulders and hands visible."),
            noCompleteReps: String(localized: "No complete push-up repetitions were measured. Start at the top with your arms straight and keep your whole body in view."),
            rangeNoun: String(localized: "elbow bend"),
            moreRange: String(localized: "greater"),
            lessRange: String(localized: "smaller"),
            liveShorterCue: String(localized: "Go lower"),
            observation: String(localized: "Your elbow bend became smaller in the last two reps."),
            nextAction: String(localized: "Keep your elbow bend similar from rep to rep."),
            rangeExplanation: String(localized: "Elbow bend is how much your elbow angle closed from the starting position, as seen by the camera. Use it only to compare your own sets from the same view."),
            rangeAccessibilityName: String(localized: "camera-observed elbow bend")
        )
    )

    /// Push-up counted from the shoulders going down and up, when the side-view rubric cannot read
    /// the arms: filmed from the front, or too close for the elbow and wrist to stay in the picture.
    /// Not in `all`: the person never picks it, `ExerciseAnalyzer` falls back to it. The rep phases
    /// are set per set from the shoulders' own travel (`withPhases`), so the phone can stand a
    /// metre or four metres away. The 0.06 image widths below is the least travel it accepts.
    /// Tuned on 3 real push-up sets (14 October 2026), a product hypothesis, not a validated standard.
    static let pushUpShoulders = ExerciseDefinition(
        kind: .pushUp,
        rubricVersion: "push-up-shoulders-v2",
        expectedView: .any,
        evidence: EvidenceRequirement(joints: [.shoulder], anchor: .wrist),
        signal: .shoulderDrop,
        phases: RepPhases(leaveTop: 0.03, reachBottom: 0.1, returnFromBottom: 0.03, backAtTop: 0.03,
                          minimumDuration: minimumPushUpDuration, maximumDuration: 8.0),
        rangeUnit: .bodyLengthFraction,
        rangeDisplayScale: 0.6,
        minimumBodyScale: 0.06,
        classifierLabel: "push_up",
        posture: ExerciseDefinition.pushUp.posture,
        copy: ExerciseDefinition.pushUp.copy
    )

    /// Squat counted from the hips going down and up, when the side-view rubric cannot read the
    /// knee and ankle: filmed from the front or at an angle, with the phone low and the feet at the
    /// picture's edge, or with the athlete stepping out of the picture for a moment. The shoulders
    /// stand in for the hips when Vision loses them. Heights are in torso lengths, so the phone may
    /// stand one or four metres away. Not in `all`: `ExerciseAnalyzer` falls back to it, and its
    /// rep phases follow the set's own travel (`withPhases`). The 0.3 torso lengths below is the
    /// least travel it accepts, about the hip travel of the side rubric's shallowest rep. A product
    /// hypothesis checked on real squats (15 October 2026), not a validated standard.
    static let squatTrunk = ExerciseDefinition(
        kind: .bodyweightSquat,
        rubricVersion: "squat-trunk-v1",
        expectedView: .any,
        evidence: EvidenceRequirement(joints: [.hip], anchor: .hip),
        signal: .shoulderDrop,
        phases: RepPhases(leaveTop: 0.12, reachBottom: 0.3, returnFromBottom: 0.08, backAtTop: 0.08,
                          minimumDuration: SquatRubric.minimumRepDuration,
                          maximumDuration: SquatRubric.maximumRepDuration),
        rangeUnit: .bodyLengthFraction,
        rangeDisplayScale: 1.2,
        minimumBodyScale: 0.3,
        classifierLabel: "squat",
        posture: ExerciseDefinition.squat.posture,
        copy: ExerciseDefinition.squat.copy
    )

    func withPhases(_ phases: RepPhases) -> ExerciseDefinition {
        ExerciseDefinition(kind: kind, rubricVersion: rubricVersion, expectedView: expectedView,
                           evidence: evidence, signal: signal, phases: phases, rangeUnit: rangeUnit,
                           rangeDisplayScale: rangeDisplayScale, minimumBodyScale: minimumBodyScale,
                           classifierLabel: classifierLabel, posture: posture, copy: copy)
    }

    /// Side-view static lunge (split squat): feet stay planted, measured as knee bend on the
    /// camera-facing leg (hip, knee, ankle).
    static let staticLunge = ExerciseDefinition(
        kind: .staticLunge,
        rubricVersion: "static-lunge-side-v6",
        expectedView: .side,
        evidence: EvidenceRequirement(joints: [.hip, .knee, .ankle], anchor: .ankle),
        signal: .jointBend(from: .hip, vertex: .knee, to: .ankle),
        phases: RepPhases(leaveTop: 20, reachBottom: 35, returnFromBottom: 10, backAtTop: 15,
                          minimumDuration: 0.5, maximumDuration: 8.0),
        rangeUnit: .degrees,
        rangeDisplayScale: 120,
        minimumBodyScale: 0.03,
        classifierLabel: "static_lunge",
        posture: PostureRule(
            cueKind: .torsoTiltIncreased, minimumIncrease: 12,
            observation: String(localized: "Your torso tilted farther from upright in the last two reps."),
            nextAction: String(localized: "Try keeping your torso angle similar from rep to rep.")
        ),
        copy: ExerciseCopy(
            name: String(localized: "Static lunge"),
            shareNoun: String(localized: "lunge"),
            setupTitle: String(localized: "Lunge check"),
            placementTitle: String(localized: "Place your iPhone"),
            placementDetail: String(localized: "At hip height, a few steps away."),
            stanceTitle: String(localized: "Stand sideways in a split stance"),
            stanceDetail: String(localized: "Keep both feet planted and the same front leg for each set."),
            framingPrompt: String(localized: "Stand sideways. Show head to toe."),
            checkingVisibility: String(localized: "Checking leg visibility"),
            showJoints: String(localized: "Show hip, knee and ankle"),
            jointsVisible: String(localized: "Hip, knee and ankle visible"),
            keepJointsVisible: String(localized: "Keep your hip, knee and ankle visible for the whole set."),
            bodyTooSmall: String(localized: "Finn couldn’t measure your knee angle. Keep your side to the camera and your whole body in view."),
            retakeHint: String(localized: "Move the phone farther back and keep your hip, knee, and ankle visible."),
            noCompleteReps: String(localized: "No complete lunge repetitions were measured. Start standing tall in your split stance and keep your whole body in view."),
            rangeNoun: String(localized: "knee bend"),
            moreRange: String(localized: "greater"),
            lessRange: String(localized: "smaller"),
            liveShorterCue: String(localized: "Go lower"),
            observation: String(localized: "Your knee bend became smaller in the last two reps."),
            nextAction: String(localized: "Keep your knee bend similar from rep to rep."),
            rangeExplanation: String(localized: "Knee bend is how much the knee angle on the side facing the camera closed from the starting position. Use it only to compare your own sets from the same view and front leg."),
            rangeAccessibilityName: String(localized: "camera-observed knee bend")
        )
    )

    /// Side-view stiff-leg deadlift, measured as hip hinge (shoulder, hip, knee). Feet stay planted.
    static let stiffLegDeadlift = ExerciseDefinition(
        kind: .stiffLegDeadlift,
        rubricVersion: "stiff-leg-deadlift-side-v6",
        expectedView: .side,
        evidence: EvidenceRequirement(joints: [.shoulder, .hip, .knee, .ankle], anchor: .ankle),
        signal: .jointBend(from: .shoulder, vertex: .hip, to: .knee),
        phases: RepPhases(leaveTop: 20, reachBottom: 35, returnFromBottom: 10, backAtTop: 15,
                          minimumDuration: 0.6, maximumDuration: 10.0),
        rangeUnit: .degrees,
        rangeDisplayScale: 120,
        minimumBodyScale: 0.03,
        classifierLabel: "stiff_leg_deadlift",
        posture: PostureRule(
            cueKind: .kneeBendIncreased, minimumIncrease: 12,
            observation: String(localized: "Your knees bent more during the last two hinges."),
            nextAction: String(localized: "Try keeping a comfortable, similar knee bend through each hinge.")
        ),
        copy: ExerciseCopy(
            name: String(localized: "Stiff-leg deadlift"),
            shareNoun: String(localized: "stiff-leg deadlift"),
            setupTitle: String(localized: "Deadlift check"),
            placementTitle: String(localized: "Place your iPhone"),
            placementDetail: String(localized: "At hip height, a few steps away."),
            stanceTitle: String(localized: "Stand sideways"),
            stanceDetail: String(localized: "Start standing tall, with your whole body in view."),
            framingPrompt: String(localized: "Stand sideways. Show head to toe."),
            checkingVisibility: String(localized: "Checking body visibility"),
            showJoints: String(localized: "Show shoulder, hip, knee and ankle"),
            jointsVisible: String(localized: "Shoulder, hip, knee and ankle visible"),
            keepJointsVisible: String(localized: "Keep your shoulder, hip and knee visible for the whole set."),
            bodyTooSmall: String(localized: "Finn couldn’t measure your hip angle. Keep your side to the camera and your whole body in view."),
            retakeHint: String(localized: "Move the phone farther back and keep your shoulder, hip, knee, and ankle visible."),
            noCompleteReps: String(localized: "No complete stiff-leg deadlift repetitions were measured. Start standing tall and keep your whole body in view."),
            rangeNoun: String(localized: "hip hinge"),
            moreRange: String(localized: "greater"),
            lessRange: String(localized: "smaller"),
            liveShorterCue: String(localized: "Hips further back"),
            observation: String(localized: "Your hip hinge became smaller in the last two reps."),
            nextAction: String(localized: "Keep your hip hinge similar from rep to rep."),
            rangeExplanation: String(localized: "Hip hinge is how much the angle between your torso and thigh closed from the starting position, as seen by the camera. Use it only to compare your own sets from the same view."),
            rangeAccessibilityName: String(localized: "camera-observed hip hinge")
        )
    )

    /// Pull-up from any view, measured as how far the shoulders rise from the hang, as a share of
    /// the arm's length, with the hands on the bar staying still. Grip (overhand, underhand,
    /// neutral) cannot be seen in 2D pose, so Finn does not name it.
    static let pullUp = ExerciseDefinition(
        kind: .pullUp,
        rubricVersion: "pull-up-v1",
        expectedView: .any,
        evidence: EvidenceRequirement(joints: [.shoulder, .hip], anchor: .wrist),
        signal: .verticalRise(joint: .shoulder, reference: .wrist),
        phases: RepPhases(leaveTop: 0.15, reachBottom: 0.55, returnFromBottom: 0.08, backAtTop: 0.12,
                          minimumDuration: 0.6, maximumDuration: 10.0),
        rangeUnit: .bodyLengthFraction,
        rangeDisplayScale: 1.0,
        minimumBodyScale: 0.06,
        classifierLabel: "pull_up",
        posture: PostureRule(
            cueKind: .swingIncreased, minimumIncrease: 0.15,
            observation: String(localized: "Your body swung more at the top of the last two reps."),
            nextAction: String(localized: "Try keeping your legs still under you on each pull.")
        ),
        copy: ExerciseCopy(
            name: String(localized: "Pull-up"),
            shareNoun: String(localized: "pull-up"),
            setupTitle: String(localized: "Pull-up check"),
            placementTitle: String(localized: "Place your iPhone"),
            placementDetail: String(localized: "At chest height, a few steps from the bar, with your hands and feet in view."),
            stanceTitle: String(localized: "Start from a hang"),
            stanceDetail: String(localized: "Straight arms, hands on the bar. Side, front or back to the phone all work."),
            framingPrompt: String(localized: "Show hands to feet."),
            checkingVisibility: String(localized: "Checking arm visibility"),
            showJoints: String(localized: "Show shoulders, hips and hands"),
            jointsVisible: String(localized: "Shoulders and hips visible"),
            keepJointsVisible: String(localized: "Keep your shoulders, hips and hands in view for the whole set."),
            bodyTooSmall: String(localized: "Finn couldn’t measure your arm length. Move the phone a little closer, with the bar in view."),
            retakeHint: String(localized: "Keep your hands, shoulders and hips in view, from the side, the front or the back."),
            noCompleteReps: String(localized: "No complete pull-ups were measured. Start from a hang with straight arms and pull until your chin passes your hands."),
            rangeNoun: String(localized: "pull height"),
            moreRange: String(localized: "higher"),
            lessRange: String(localized: "lower"),
            liveShorterCue: String(localized: "Pull higher"),
            observation: String(localized: "Your pulls got lower in the last two reps."),
            nextAction: String(localized: "Try a pace you can keep consistent."),
            rangeExplanation: String(localized: "Pull height is how far your shoulders rose from the hang, as a share of your arm length, as seen by the camera. Use it only to compare your own sets from the same view."),
            rangeAccessibilityName: String(localized: "camera-observed pull height")
        )
    )

    /// Bar muscle-up from any view: the same rise as a pull-up, but at least 1.2 arm lengths from
    /// the hang, which puts the shoulders above the hands. A pull-up, however high, stays below.
    static let muscleUp = ExerciseDefinition(
        kind: .muscleUp,
        rubricVersion: "muscle-up-v1",
        expectedView: .any,
        evidence: EvidenceRequirement(joints: [.shoulder, .hip], anchor: .wrist),
        signal: .verticalRise(joint: .shoulder, reference: .wrist),
        phases: RepPhases(leaveTop: 0.15, reachBottom: 1.2, returnFromBottom: 0.1, backAtTop: 0.12,
                          minimumDuration: 1.0, maximumDuration: 12.0),
        rangeUnit: .bodyLengthFraction,
        rangeDisplayScale: 2.0,
        minimumBodyScale: 0.06,
        classifierLabel: "muscle_up",
        posture: PostureRule(
            cueKind: .swingIncreased, minimumIncrease: 0.15,
            observation: String(localized: "Your body swung more at the top of the last two reps."),
            nextAction: String(localized: "Try keeping your legs still under you on each pull.")
        ),
        copy: ExerciseCopy(
            name: String(localized: "Muscle-up"),
            shareNoun: String(localized: "muscle-up"),
            setupTitle: String(localized: "Muscle-up check"),
            placementTitle: String(localized: "Place your iPhone"),
            placementDetail: String(localized: "At chest height, a few steps from the bar, with the space above it in view."),
            stanceTitle: String(localized: "Start from a hang"),
            stanceDetail: String(localized: "Straight arms, hands on the bar. Keep the space above the bar in view."),
            framingPrompt: String(localized: "Show the bar, the space above it and your feet."),
            checkingVisibility: String(localized: "Checking arm visibility"),
            showJoints: String(localized: "Show shoulders, hips and hands"),
            jointsVisible: String(localized: "Shoulders and hips visible"),
            keepJointsVisible: String(localized: "Keep your shoulders, hips and hands in view for the whole set."),
            bodyTooSmall: String(localized: "Finn couldn’t measure your arm length. Move the phone a little further back, with the bar and the space above it in view."),
            retakeHint: String(localized: "Keep your hands, shoulders and hips in view above and below the bar."),
            noCompleteReps: String(localized: "No complete muscle-ups were measured: your shoulders did not get above your hands. If you meant pull-ups, choose Pull-up."),
            rangeNoun: String(localized: "rise"),
            moreRange: String(localized: "higher"),
            lessRange: String(localized: "lower"),
            liveShorterCue: String(localized: "Pull higher"),
            observation: String(localized: "Your rise got lower in the last two reps."),
            nextAction: String(localized: "Try a pace you can keep consistent."),
            rangeExplanation: String(localized: "Rise is how far your shoulders went up from the hang, as a share of your arm length, as seen by the camera. Above 100% your shoulders are above your hands."),
            rangeAccessibilityName: String(localized: "camera-observed rise")
        )
    )
}
