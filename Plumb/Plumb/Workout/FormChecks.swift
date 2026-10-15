import Foundation

/// One coaching check a coach would make from the side, measured at the bottom of each rep with
/// `BodySegments`. Each threshold below is a product hypothesis checked against labeled side-view
/// videos (see `docs/validation/form-checks-v1.md`), not a validated standard or a safety limit.
/// Nothing here can be seen only from the front (knees caving in, elbows flaring), so no check
/// reads it.
nonisolated enum FormCheck: String, CaseIterable, Codable, Sendable {
    // Listed in the order the advice is given when several show in one set: the body's shape first,
    // then how deep the rep went.
    case pushUpHipsSag
    case pushUpHipsPike
    case pushUpDepth
    case squatChestDrop
    case squatDepth
    case lungeTorsoLean
    case lungeFrontKnee
    case deadliftKneeBend
    case deadliftHinge

    // MARK: Thresholds
    //
    // Squat and push-up limits were set on the side-view videos of the Mendeley "Seven Fitness
    // Exercises with Good/Bad Form Labels" set (CC BY 4.0), 25 good and 25 bad sets of each, kept off
    // this repository; `docs/validation/form-checks-v1.md` gives how many sets each catches and
    // wrongly accuses. Lunge and stiff-leg deadlift limits come from common coaching cues only: that
    // set has neither exercise.

    /// Push-up: hip more than this many torso lengths below the shoulder-to-ankle line at the bottom
    /// (hips sagging).
    static let pushUpMaximumSag = 0.2
    /// Push-up: hip more than this many torso lengths above that line (hips piked up).
    static let pushUpMaximumPike = 0.2
    /// Push-up: elbow angle at the bottom above this many degrees. A full push-up reaches about 90°;
    /// 110° still accused 4 of 15 good sets, Vision's elbow and wrist jitter at the bottom.
    static let pushUpMaximumBottomElbow = 120.0
    /// Squat: thigh more than this many degrees above level at the bottom. Level (0°) is a parallel
    /// squat; Vision's hip point sits above the hip crease, and good sets bottomed out around 15°.
    static let squatMaximumThighAboveLevel = 30.0
    /// Squat: torso leaning more than this many degrees beyond the shins at the bottom. Coaches cue a
    /// torso roughly parallel to the shins; the bad squats of the labeled set do not show this fault,
    /// so the limit is set high to keep false alarms rare.
    static let squatMaximumTorsoBeyondShin = 45.0
    /// Lunge: torso more than this many degrees from upright at the bottom.
    static let lungeMaximumTorsoLean = 25.0
    /// Lunge: front knee angle above this many degrees at the bottom. A full split squat brings it
    /// near 90°.
    static let lungeMaximumFrontKnee = 115.0
    /// Squat: the thigh is read only when it looks at least this share of its standing length. Seen
    /// from the side it keeps its length; much shorter, the camera is not side-on or Vision misplaced
    /// the hip, and its angle means nothing.
    static let squatMinimumThighShare = 0.7
    /// A thigh leaning at least this far from vertical at the bottom of a lunge is the front leg;
    /// the back thigh stays closer to vertical.
    static let lungeFrontThighTilt = 45.0
    /// Stiff-leg deadlift: knees bent more than this many degrees at the bottom of the hinge.
    static let deadliftMaximumKneeBend = 30.0
    /// Stiff-leg deadlift: torso less than this many degrees from upright at the bottom.
    static let deadliftMinimumTorsoLean = 50.0

    /// A check gives advice only when its fault shows in at least this many reps of the set...
    static let minimumFaultyReps = 2
    /// ...and in at least this share of the reps it could read. Two reps out of eighteen is noise:
    /// without it, the squat depth check accused 8 of 15 good sets at 20°.
    static let minimumFaultyShare = 0.25

    // MARK: What each check reads

    var exercise: ExerciseKind {
        switch self {
        case .pushUpHipsSag, .pushUpHipsPike, .pushUpDepth: .pushUp
        case .squatChestDrop, .squatDepth: .bodyweightSquat
        case .lungeTorsoLean, .lungeFrontKnee: .staticLunge
        case .deadliftKneeBend, .deadliftHinge: .stiffLegDeadlift
        }
    }

    static func checks(for exercise: ExerciseKind) -> [FormCheck] {
        allCases.filter { $0.exercise == exercise }
    }

    /// Joints the check reads, on the side the camera sees best.
    var joints: [JointRole] {
        switch self {
        case .pushUpHipsSag, .pushUpHipsPike: [.shoulder, .hip, .knee]
        case .pushUpDepth: [.shoulder, .elbow, .wrist]
        case .squatChestDrop: [.shoulder, .hip, .knee, .ankle]
        case .squatDepth: [.hip, .knee]
        case .lungeTorsoLean: [.shoulder, .hip]
        case .lungeFrontKnee: [.hip, .knee, .ankle]
        case .deadliftKneeBend: [.hip, .knee, .ankle]
        case .deadliftHinge: [.shoulder, .hip]
        }
    }

    /// The reading in one frame, or nil when a joint it needs is not clear.
    /// Confidence each joint needs for this check. The body line accepts the rep count's 0.3: Vision
    /// gives the hips of a body lying level low confidence (on 48 side-view push-up videos the near hip
    /// reached 0.5 in 13% of frames and 0.3 in 62%), and the median over a rep's bottom frames
    /// steadies the reading.
    var minimumConfidence: Double {
        switch self {
        case .pushUpHipsSag, .pushUpHipsPike: EvidenceRubric.minimumJointConfidence
        default: BodySegments.supportingConfidence
        }
    }

    /// The reading in one frame, or nil when a joint it needs is not clear. `standingThigh` is the
    /// thigh's length when the person stands (the squat depth check needs it).
    func measure(_ frame: PoseFrame, side: BodySide, standingThigh: Double? = nil) -> Double? {
        let body = BodySegments(frame: frame, side: side, minimumConfidence: minimumConfidence)
        switch self {
        case .pushUpHipsSag, .pushUpHipsPike: return body.hipOffsetFromBodyLine
        case .pushUpDepth: return body.elbowAngle
        case .squatChestDrop:
            guard let torso = body.torsoTilt, let shin = body.shinTilt else { return nil }
            return torso - shin
        case .squatDepth:
            guard let thigh = body.thigh?.length, let standingThigh,
                  thigh >= Self.squatMinimumThighShare * standingThigh else { return nil }
            return body.thighAboveLevel
        case .lungeTorsoLean: return body.torsoTilt
        case .lungeFrontKnee:
            // The front leg is the one whose thigh leans most toward level; it may be the far leg.
            let legs = [side, side == .left ? BodySide.right : .left]
                .map { BodySegments(frame: frame, side: $0) }
                .compactMap { leg -> (tilt: Double, knee: Double)? in
                    guard let tilt = leg.thighTilt, let knee = leg.kneeAngle else { return nil }
                    return (tilt, knee)
                }
            guard let front = legs.max(by: { $0.tilt < $1.tilt }), front.tilt >= Self.lungeFrontThighTilt else {
                return nil
            }
            return front.knee
        case .deadliftKneeBend: return body.kneeAngle.map { 180 - $0 }
        case .deadliftHinge: return body.torsoTilt
        }
    }

    func isFault(_ value: Double) -> Bool {
        switch self {
        case .pushUpHipsSag: value > Self.pushUpMaximumSag
        case .pushUpHipsPike: value < -Self.pushUpMaximumPike
        case .pushUpDepth: value > Self.pushUpMaximumBottomElbow
        case .squatChestDrop: value > Self.squatMaximumTorsoBeyondShin
        case .squatDepth: value > Self.squatMaximumThighAboveLevel
        case .lungeTorsoLean: value > Self.lungeMaximumTorsoLean
        case .lungeFrontKnee: value > Self.lungeMaximumFrontKnee
        case .deadliftKneeBend: value > Self.deadliftMaximumKneeBend
        case .deadliftHinge: value < Self.deadliftMinimumTorsoLean
        }
    }

    // MARK: What it says

    /// What was checked, for "Plumb couldn't check your ...".
    var subject: String {
        switch self {
        case .pushUpHipsSag, .pushUpHipsPike: "body line"
        case .pushUpDepth: "push-up depth"
        case .squatChestDrop: "chest position"
        case .squatDepth: "squat depth"
        case .lungeTorsoLean: "torso position"
        case .lungeFrontKnee: "front knee bend"
        case .deadliftKneeBend: "knee bend"
        case .deadliftHinge: "hip hinge"
        }
    }

    /// The pattern in a few words, for the most frequent pattern.
    var title: String {
        switch self {
        case .pushUpHipsSag: "Hips sagging below your body line"
        case .pushUpHipsPike: "Hips raised above your body line"
        case .pushUpDepth: "Elbows not bending to 90°"
        case .squatChestDrop: "Chest dropping forward at the bottom"
        case .squatDepth: "Hips staying above your knees"
        case .lungeTorsoLean: "Torso leaning forward"
        case .lungeFrontKnee: "Front knee not bending to 90°"
        case .deadliftKneeBend: "Knees bending like a squat"
        case .deadliftHinge: "Hinge stopping early"
        }
    }

    /// The sentence on the result, with the reps that showed it and the typical reading.
    func observation(reps: [Int], typical: Double) -> String {
        let inReps = "in \(FormChecks.list(reps))"
        let degrees = Int(typical.rounded())
        let share = Int((abs(typical) * 100).rounded())
        return switch self {
        case .pushUpHipsSag:
            "Your hips sagged below the line from your shoulders to your ankles \(inReps), by about \(share)% of your torso length."
        case .pushUpHipsPike:
            "Your hips rose above the line from your shoulders to your ankles \(inReps), by about \(share)% of your torso length."
        case .pushUpDepth:
            "Your elbows stayed at about \(degrees)° at the bottom \(inReps). A full push-up brings them to about 90°."
        case .squatChestDrop:
            "Your chest dropped forward at the bottom \(inReps): your torso leaned about \(degrees)° more than your shins."
        case .squatDepth:
            "Your hips stayed above your knees at the bottom \(inReps): your thighs were about \(degrees)° above level."
        case .lungeTorsoLean:
            "Your torso leaned about \(degrees)° forward at the bottom \(inReps)."
        case .lungeFrontKnee:
            "Your front knee stayed at about \(degrees)° at the bottom \(inReps). A full lunge brings it near 90°."
        case .deadliftKneeBend:
            "Your knees bent about \(degrees)° at the bottom of the hinge \(inReps), more like a squat than a stiff-leg deadlift."
        case .deadliftHinge:
            "Your torso stopped at about \(degrees)° from upright \(inReps), early in the hinge."
        }
    }

    var nextAction: String {
        switch self {
        case .pushUpHipsSag: "Squeeze your glutes and brace your stomach so your body stays one straight line."
        case .pushUpHipsPike: "Lower your hips until your shoulders, hips and ankles line up."
        case .pushUpDepth: "Lower your chest until your elbows reach about 90°, or do fewer reps you can take all the way down."
        case .squatChestDrop: "Keep your chest up: aim for a torso about as tilted as your shins."
        case .squatDepth: "If it feels comfortable, sit a little lower, toward knee height."
        case .lungeTorsoLean: "Stay tall: keep your shoulders over your hips as you lower."
        case .lungeFrontKnee: "Lower your back knee toward the floor until your front thigh is close to level."
        case .deadliftKneeBend: "Keep a slight, fixed bend in your knees and push your hips back instead."
        case .deadliftHinge: "Push your hips farther back and let your torso lower more, as far as feels comfortable."
        }
    }

    /// A few words to show and say during the set, readable from a few steps away.
    var liveCue: String {
        switch self {
        case .pushUpHipsSag: "Lift your hips"
        case .pushUpHipsPike: "Lower your hips"
        case .pushUpDepth: "Go lower"
        case .squatChestDrop: "Chest up"
        case .squatDepth: "Sit lower"
        case .lungeTorsoLean: "Stay tall"
        case .lungeFrontKnee: "Go lower"
        case .deadliftKneeBend: "Straighter knees"
        case .deadliftHinge: "Hips further back"
        }
    }

    var cueKind: CueKind {
        switch self {
        case .pushUpHipsSag: .pushUpHipsSag
        case .pushUpHipsPike: .pushUpHipsPike
        case .pushUpDepth: .pushUpDepth
        case .squatChestDrop: .squatChestDrop
        case .squatDepth: .squatDepth
        case .lungeTorsoLean: .lungeTorsoLean
        case .lungeFrontKnee: .lungeFrontKnee
        case .deadliftKneeBend: .deadliftKneeBend
        case .deadliftHinge: .deadliftHinge
        }
    }

    init?(cueKind: CueKind) {
        self.init(rawValue: cueKind.rawValue)
    }
}

/// A check whose fault showed in at least `FormCheck.minimumFaultyReps` reps of a set.
nonisolated struct FormFinding: Equatable, Sendable {
    let check: FormCheck
    /// The reps that showed the fault.
    let reps: [Int]
    /// Reps the check could read.
    let judged: Int
    /// Median reading over the faulty reps, in the check's unit.
    let typical: Double

    var observation: String { check.observation(reps: reps, typical: typical) }

    var cue: Cue {
        Cue(kind: check.cueKind, repNumbers: reps, earlierMedian: typical, laterMedian: typical,
            observation: observation, nextAction: check.nextAction)
    }
}

/// What the form checks found in one set: faults in advice order, and sentences for the result
/// (pull-up facts, secondary faults, and what Plumb could not check and why).
nonisolated struct FormReview: Equatable, Sendable {
    var findings: [FormFinding] = []
    var notes: [String] = []
}

/// Facts measured on each rep of a set, beyond the count. For the squat, push-up, lunge and
/// stiff-leg deadlift, the coaching checks of `FormCheck`; for pull-ups and muscle-ups, whether the
/// chin passed the hands, whether the arms were straight at the start of the rep, and how much the
/// body swung. Each check is a camera measurement from the side, not a judgment of technique;
/// when a joint it needs is not tracked, it says so instead of guessing.
nonisolated enum FormChecks {
    /// Elbow angle from which an arm counts as straight at the bottom of a pull-up.
    static let straightArmDegrees = 150.0
    /// Hip travel, forward and back, above which the body is said to swing (share of arm length).
    static let swingShare = 0.35

    static func sentences(for analysis: SetAnalysis, frames: [PoseFrame],
                          definition: ExerciseDefinition) -> [String] {
        review(analysis, frames: frames, definition: definition).notes
    }

    /// The checks of `definition`'s exercise over a measured set. `viewCheck` follows the person's
    /// camera-angle option: when it is on and Vision 3D saw the person at an angle, the side-view
    /// checks say nothing, since an angled view bends every 2D angle.
    static func review(_ analysis: SetAnalysis, frames: [PoseFrame], definition: ExerciseDefinition,
                       viewCheck: ExerciseAnalyzer.ViewCheckPolicy = .enforce) -> FormReview {
        switch definition.kind {
        case .pullUp, .muscleUp:
            return FormReview(notes: pullChecks(analysis, frames: frames, definition: definition))
        case .bodyweightSquat, .pushUp, .staticLunge, .stiffLegDeadlift:
            return sideChecks(analysis, frames: frames, definition: definition, viewCheck: viewCheck)
        }
    }

    // MARK: Side-view checks

    private static func sideChecks(_ analysis: SetAnalysis, frames: [PoseFrame], definition: ExerciseDefinition,
                                   viewCheck: ExerciseAnalyzer.ViewCheckPolicy) -> FormReview {
        // Push-ups counted from the shoulders (filmed from the front, or the arm out of the picture)
        // have no side-view joints to read; the result already says so.
        guard !analysis.reps.isEmpty, analysis.rubricVersion != ExerciseDefinition.pushUpShoulders.rubricVersion,
              case .usable(let side) = EvidenceGate.assess(frames, requirement: definition.evidence) else {
            return FormReview()
        }
        if viewCheck == .enforce {
            switch ViewCheck.assess(frames, expected: .side) {
            case .angled(let deviation, _), .mismatch(let deviation, _):
                // Exercises filmed only from the side already get "turn a little" from the analysis.
                guard definition.expectedView == .any else { return FormReview() }
                return FormReview(notes: [
                    "Plumb checks \(definition.copy.shareNoun) form from the side only. It saw you about \(Int(deviation.rounded()))° from side-on, so it gives no form advice for this set.",
                ])
            case .matches, .unavailable:
                break
            }
        }
        let bottoms = analysis.reps.map { rep in (rep, bottomFrames(of: rep, in: frames, definition: definition)) }
        let thigh = standingThigh(frames, side: side)
        var review = FormReview()
        for check in FormCheck.checks(for: definition.kind) {
            let readings = bottoms.compactMap { rep, window -> (Int, Double)? in
                let values = window.compactMap { check.measure($0, side: side, standingThigh: thigh) }
                guard values.count * 2 > window.count, !values.isEmpty else { return nil }
                return (rep.number, median(values))
            }
            guard readings.count >= FormCheck.minimumFaultyReps, readings.count * 2 >= analysis.reps.count else {
                review.notes.append(cannotCheck(check, bottoms: bottoms.flatMap(\.1), side: side))
                continue
            }
            let faulty = readings.filter { check.isFault($0.1) }
            guard faulty.count >= FormCheck.minimumFaultyReps,
                  Double(faulty.count) >= FormCheck.minimumFaultyShare * Double(readings.count) else { continue }
            review.findings.append(FormFinding(check: check, reps: faulty.map(\.0), judged: readings.count,
                                               typical: median(faulty.map(\.1))))
        }
        // Sag and pike read the same line; when both show, the one seen on more reps is kept.
        if let sag = review.findings.firstIndex(where: { $0.check == .pushUpHipsSag }),
           let pike = review.findings.firstIndex(where: { $0.check == .pushUpHipsPike }) {
            review.findings.remove(at: review.findings[sag].reps.count >= review.findings[pike].reps.count ? pike : sag)
        }
        // The first finding becomes the set's observation; the others are listed as facts.
        review.notes.insert(contentsOf: review.findings.dropFirst().map(\.observation), at: 0)
        return review
    }

    /// The frames around a rep's deepest point (up to two on each side, within the rep), where every
    /// check reads its value. A median over them keeps one jittery frame from deciding.
    static func bottomFrames(of rep: RepMetric, in frames: [PoseFrame],
                             definition: ExerciseDefinition) -> [PoseFrame] {
        guard let deepest = ExerciseAnalyzer.deepestFrame(of: rep, in: frames, as: definition),
              let index = frames.firstIndex(where: { $0.time == deepest.time }) else { return [] }
        return frames[max(0, index - 2)...min(frames.count - 1, index + 2)]
            .filter { $0.time >= rep.startTime && $0.time <= rep.endTime }
    }

    /// The thigh's length over the set (its 90th percentile, the length seen standing).
    static func standingThigh(_ frames: [PoseFrame], side: BodySide) -> Double? {
        let lengths = frames.compactMap { BodySegments(frame: $0, side: side).thigh?.length }.sorted()
        guard lengths.count >= 5 else { return nil }
        return lengths[Int(Double(lengths.count - 1) * 0.9)]
    }

    /// Why a check said nothing: the joint it needs that was least often clear at the bottom of the
    /// reps, or, with every joint clear, a view that does not show the measurement.
    private static func cannotCheck(_ check: FormCheck, bottoms: [PoseFrame], side: BodySide) -> String {
        if check == .lungeFrontKnee {
            let legSeen = bottoms.contains { frame in
                BodySegments(frame: frame, side: side).kneeAngle != nil
            }
            if legSeen {
                return "Plumb couldn’t check your front knee bend: it saw only your back leg clearly. Turn so your front leg is nearer the phone."
            }
        }
        let weakest = check.joints.min { first, second in
            clearCount(first, in: bottoms, side: side, minimum: check.minimumConfidence)
                < clearCount(second, in: bottoms, side: side, minimum: check.minimumConfidence)
        } ?? check.joints[0]
        if clearCount(weakest, in: bottoms, side: side, minimum: check.minimumConfidence) * 2 > bottoms.count {
            return "Plumb couldn’t check your \(check.subject) from this camera position. Keep your side square to the phone."
        }
        return "Plumb couldn’t check your \(check.subject): your \(weakest.rawValue) wasn’t clear enough at the bottom of the reps."
    }

    private static func clearCount(_ role: JointRole, in frames: [PoseFrame], side: BodySide,
                                   minimum: Double) -> Int {
        frames.filter {
            ($0.joints[role.joint(on: side)]?.confidence ?? 0) >= minimum
        }.count
    }

    // MARK: Pull-ups and muscle-ups

    private static func pullChecks(_ analysis: SetAnalysis, frames: [PoseFrame],
                                   definition: ExerciseDefinition) -> [String] {
        guard !analysis.reps.isEmpty,
              case .usable(let side) = EvidenceGate.assess(frames, requirement: definition.evidence) else { return [] }
        var sentences: [String] = []
        let total = analysis.reps.count

        // Chin above the hands at the top of each rep (the bar itself is not tracked).
        if definition.kind == .pullUp {
            let tops = analysis.reps.map { ExerciseAnalyzer.deepestFrame(of: $0, in: frames, as: definition) }
            let judged = zip(analysis.reps, tops).compactMap { rep, frame -> (Int, Bool)? in
                guard let frame, let chin = chinAboveHands(frame) else { return nil }
                return (rep.number, chin)
            }
            if judged.count * 2 >= total {
                let missed = judged.filter { !$0.1 }.map(\.0)
                sentences.append(missed.isEmpty
                    ? "Chin above your hands in all \(judged.count) reps Plumb could check."
                    : "Chin above your hands in \(judged.count - missed.count) of \(judged.count) reps; not in \(list(missed)).")
            }
        }

        // Straight arms at the hang before each rep: the frame with the lowest shoulders between
        // the previous rep's end and this rep's start.
        let starts = analysis.reps.enumerated().compactMap { index, rep -> (Int, Double)? in
            let from = index == 0 ? (frames.first?.time ?? 0) : analysis.reps[index - 1].endTime
            let hang = frames.filter { $0.time >= from && $0.time <= rep.startTime + 0.05 }
                .compactMap { frame -> (PoseFrame, Double)? in
                    guard let shoulder = frame.joints[JointRole.shoulder.joint(on: side)],
                          shoulder.confidence >= EvidenceRubric.minimumJointConfidence else { return nil }
                    return (frame, shoulder.y)
                }
                .max { $0.1 < $1.1 }?.0
            return hang.flatMap { elbowAngle($0, side: side) }.map { (rep.number, $0) }
        }
        if starts.count * 2 >= total {
            let bent = starts.filter { $0.1 < straightArmDegrees }.map(\.0)
            sentences.append(bent.isEmpty
                ? "Arms straight at the start of every rep."
                : "Arms not fully straight at the start of \(list(bent)).")
        }

        // Swing: how far the hips travel forward and back during the set.
        if let swing = swing(frames, side: side), swing >= swingShare {
            sentences.append("Your hips swung about \(Int((swing * 100).rounded()))% of your arm length forward and back. A still body makes each rep count the same.")
        }
        return sentences
    }

    /// Nose above the higher hand, when the nose and at least one wrist are tracked.
    static func chinAboveHands(_ frame: PoseFrame) -> Bool? {
        guard let nose = frame.joints[.nose], nose.confidence >= EvidenceRubric.minimumJointConfidence else {
            return nil
        }
        let wrists = [frame.joints[.leftWrist], frame.joints[.rightWrist]].compactMap { $0 }
            .filter { $0.confidence >= EvidenceRubric.minimumJointConfidence }
        guard let hands = wrists.map(\.y).min() else { return nil }
        return nose.y < hands
    }

    private static func elbowAngle(_ frame: PoseFrame, side: BodySide) -> Double? {
        BodySegments(frame: frame, side: side, minimumConfidence: EvidenceRubric.minimumJointConfidence).elbowAngle
    }

    /// Spread of hip position across the set (10th to 90th percentile), over the arm length.
    private static func swing(_ frames: [PoseFrame], side: BodySide) -> Double? {
        let points = frames.compactMap { frame -> (hipX: Double, arm: Double)? in
            guard let hip = frame.joints[JointRole.hip.joint(on: side)],
                  let shoulder = frame.joints[JointRole.shoulder.joint(on: side)],
                  let wrist = frame.joints[JointRole.wrist.joint(on: side)],
                  min(hip.confidence, shoulder.confidence, wrist.confidence) >= EvidenceRubric.minimumJointConfidence
            else { return nil }
            let arm = hypot(shoulder.x - wrist.x, (shoulder.y - wrist.y) * frame.aspectRatio)
            return (hip.x, arm)
        }
        guard points.count >= 10 else { return nil }
        let xs = points.map(\.hipX).sorted()
        let arms = points.map(\.arm).sorted()
        let arm = arms[Int(Double(arms.count - 1) * 0.9)]
        guard arm > 0 else { return nil }
        return (xs[Int(Double(xs.count - 1) * 0.9)] - xs[Int(Double(xs.count - 1) * 0.1)]) / arm
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    /// "rep 2", "rep 2 and rep 5", "rep 2, rep 3 and rep 5".
    static func list(_ reps: [Int]) -> String {
        let names = reps.map { "rep \($0)" }
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
    }
}
