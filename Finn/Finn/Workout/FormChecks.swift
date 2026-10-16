import Foundation

/// One coaching check a coach would make from the side, measured across each rep with
/// `BodySegments`. Each threshold below is a product hypothesis checked against labelled side-view
/// videos (see `docs/validation/form-checks-v1.md`), not a validated standard or a safety limit.
/// Nothing here can be seen only from the front (knees caving in, elbows flaring), so no check
/// reads it.
nonisolated enum FormCheck: String, CaseIterable, Codable, Sendable {
    // Listed in advice order when several faults show in one set: the body's shape first,
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

    /// Push-up: hip persistently below the body line by this many torso lengths (hips sagging).
    /// The line uses the knee when the ankle is unclear.
    static let pushUpMaximumSag = 0.2
    /// Push-up: hip more than this many torso lengths above that line (hips piked up).
    static let pushUpMaximumPike = 0.2
    /// Push-up: elbow angle at the bottom above this many degrees. A full push-up reaches about 90°;
    /// 110° still accused 4 of 15 good sets, Vision's elbow and wrist jitter at the bottom.
    static let pushUpMaximumBottomElbow = 120.0
    /// Squat: thigh more than this many degrees above level at the bottom. Level (0°) is a parallel
    /// squat; Vision's hip point sits above the hip crease, and good sets bottomed out around 15°.
    static let squatMaximumThighAboveLevel = 30.0
    /// Squat: torso persistently leaning more than this many degrees beyond the shins. Coaches cue a
    /// torso roughly parallel to the shins; the bad squats of the labelled set do not show this fault,
    /// so the limit is set high to keep false alarms rare.
    static let squatMaximumTorsoBeyondShin = 45.0
    /// Lunge: torso persistently more than this many degrees from upright.
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
    /// Stiff-leg deadlift: knees persistently bent more than this many degrees during the hinge.
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
        case .pushUpHipsSag,
             .pushUpHipsPike,
             .pushUpDepth:
            .pushUp
        case .squatChestDrop,
             .squatDepth:
            .bodyweightSquat
        case .lungeTorsoLean,
             .lungeFrontKnee:
            .staticLunge
        case .deadliftKneeBend,
             .deadliftHinge:
            .stiffLegDeadlift
        }
    }

    static func checks(for exercise: ExerciseKind) -> [FormCheck] {
        allCases.filter { $0.exercise == exercise }
    }

    var needsBottomPosition: Bool {
        switch self {
        case .pushUpDepth,
             .squatDepth,
             .lungeFrontKnee,
             .deadliftHinge:
            true
        case .pushUpHipsSag,
             .pushUpHipsPike,
             .squatChestDrop,
             .lungeTorsoLean,
             .deadliftKneeBend:
            false
        }
    }

    /// Joints the check reads, on the side the camera sees best.
    var joints: [JointRole] {
        switch self {
        case .pushUpHipsSag,
             .pushUpHipsPike:
            [.shoulder, .hip, .knee]
        case .pushUpDepth:
            [.shoulder, .elbow, .wrist]
        case .squatChestDrop:
            [.shoulder, .hip, .knee, .ankle]
        case .squatDepth:
            [.hip, .knee]
        case .lungeTorsoLean:
            [.shoulder, .hip]
        case .lungeFrontKnee:
            [.hip, .knee, .ankle]
        case .deadliftKneeBend:
            [.hip, .knee, .ankle]
        case .deadliftHinge:
            [.shoulder, .hip]
        }
    }

    /// Confidence each joint needs for this check. The body line accepts the rep count's 0.3: Vision
    /// gives the hips of a body lying level low confidence (on 48 side-view push-up videos the near hip
    /// reached 0.5 in 13% of frames and 0.3 in 62%). Sustained episodes and their median readings
    /// now separate body-line faults from short tracking glitches.
    var minimumConfidence: Double {
        switch self {
        case .pushUpHipsSag,
             .pushUpHipsPike:
            EvidenceRubric.minimumJointConfidence
        default:
            BodySegments.supportingConfidence
        }
    }

    /// The reading in one frame, or nil when a joint it needs is not clear. `standingThigh` is the
    /// thigh's length when the person stands (the squat depth check needs it).
    func measure(_ frame: PoseFrame, side: BodySide, standingThigh: Double? = nil) -> Double? {
        let body = BodySegments(frame: frame, side: side, minimumConfidence: minimumConfidence)
        switch self {
        case .pushUpHipsSag,
             .pushUpHipsPike:
            return body.hipOffsetFromBodyLine
        case .pushUpDepth:
            return body.elbowAngle
        case .squatChestDrop:
            guard let torso = body.torsoTilt, let shin = body.shinTilt else {
                return nil
            }
            return torso - shin
        case .squatDepth:
            guard
                let thigh = body.thigh?.length, let standingThigh,
                thigh >= Self.squatMinimumThighShare * standingThigh else {
                return nil
            }
            return body.thighAboveLevel
        case .lungeTorsoLean:
            return body.torsoTilt
        case .lungeFrontKnee:
            // the front leg is the one whose thigh leans most towards level; it may be the far leg.
            let legs = [side, side == .left ? BodySide.right : .left]
                .map { BodySegments(frame: frame, side: $0) }
                .compactMap { leg -> (tilt: Double, knee: Double)? in
                    guard let tilt = leg.thighTilt, let knee = leg.kneeAngle else {
                        return nil
                    }
                    return (tilt, knee)
                }
            guard
                let front = legs.max(by: { $0.tilt < $1.tilt }),
                front.tilt >= Self.lungeFrontThighTilt else {
                return nil
            }
            return front.knee
        case .deadliftKneeBend:
            return body.kneeAngle.map { 180 - $0 }
        case .deadliftHinge:
            return body.torsoTilt
        }
    }

    func isFault(_ value: Double) -> Bool {
        switch self {
        case .pushUpHipsSag:
            value > Self.pushUpMaximumSag
        case .pushUpHipsPike:
            value < -Self.pushUpMaximumPike
        case .pushUpDepth:
            value > Self.pushUpMaximumBottomElbow
        case .squatChestDrop:
            value > Self.squatMaximumTorsoBeyondShin
        case .squatDepth:
            value > Self.squatMaximumThighAboveLevel
        case .lungeTorsoLean:
            value > Self.lungeMaximumTorsoLean
        case .lungeFrontKnee:
            value > Self.lungeMaximumFrontKnee
        case .deadliftKneeBend:
            value > Self.deadliftMaximumKneeBend
        case .deadliftHinge:
            value < Self.deadliftMinimumTorsoLean
        }
    }

    // MARK: What it says

    /// What was checked, for "Finn couldn't check your ...".
    var subject: String {
        switch self {
        case .pushUpHipsSag,
             .pushUpHipsPike:
            String(localized: "body line")
        case .pushUpDepth:
            String(localized: "push-up depth")
        case .squatChestDrop:
            String(localized: "chest position")
        case .squatDepth:
            String(localized: "squat depth")
        case .lungeTorsoLean:
            String(localized: "torso position")
        case .lungeFrontKnee:
            String(localized: "front knee bend")
        case .deadliftKneeBend:
            String(localized: "knee bend")
        case .deadliftHinge:
            String(localized: "hip hinge")
        }
    }

    /// The pattern in a few words, for the most frequent pattern.
    var title: String {
        switch self {
        case .pushUpHipsSag:
            String(localized: "Hips sagging below your body line")
        case .pushUpHipsPike:
            String(localized: "Hips raised above your body line")
        case .pushUpDepth:
            String(localized: "Elbows not bending to 90°")
        case .squatChestDrop:
            String(localized: "Chest dropping forward")
        case .squatDepth:
            String(localized: "Hips staying above your knees")
        case .lungeTorsoLean:
            String(localized: "Torso leaning forward")
        case .lungeFrontKnee:
            String(localized: "Front knee not bending to 90°")
        case .deadliftKneeBend:
            String(localized: "Knees bending like a squat")
        case .deadliftHinge:
            String(localized: "Hinge stopping early")
        }
    }

    /// The sentence on the result, with the reps that showed it and the typical reading.
    func observation(reps: [Int], typical: Double) -> String {
        guard typical.isFinite, abs(typical) <= 1_000 else {
            return ""
        }
        let inReps = String(localized: "in \(FormChecks.list(reps))")
        let degrees = Int(typical.rounded())
        let share = Int((abs(typical) * 100).rounded())
        return switch self {
        case .pushUpHipsSag:
            String(
                localized: "Your hips sagged below your body line \(inReps), by about \(share)% of your torso length."
            )
        case .pushUpHipsPike:
            String(
                localized: "Your hips rose above your body line \(inReps), by about \(share)% of your torso length."
            )
        case .pushUpDepth:
            String(
                localized: "Your elbows stayed at about \(degrees)° at the bottom \(inReps). A full push-up brings them to about 90°."
            )
        case .squatChestDrop:
            String(
                localized: "Your chest dropped forward \(inReps): your torso leaned about \(degrees)° more than your shins."
            )
        case .squatDepth:
            String(
                localized: "Your hips stayed above your knees at the bottom \(inReps): your thighs were about \(degrees)° above level."
            )
        case .lungeTorsoLean:
            String(localized: "Your torso leaned about \(degrees)° forward \(inReps).")
        case .lungeFrontKnee:
            String(
                localized: "Your front knee stayed at about \(degrees)° at the bottom \(inReps). A full lunge brings it near 90°."
            )
        case .deadliftKneeBend:
            String(
                localized: "Your knees bent about \(degrees)° during the hinge \(inReps), more like a squat than a stiff-leg deadlift."
            )
        case .deadliftHinge:
            String(
                localized: "Your torso stopped at about \(degrees)° from upright \(inReps), early in the hinge."
            )
        }
    }

    var nextAction: String {
        switch self {
        case .pushUpHipsSag:
            String(
                localized: "Squeeze your glutes and brace your stomach so your body stays one straight line."
            )
        case .pushUpHipsPike:
            String(
                localized: "Lower your hips until your shoulders, hips and ankles line up."
            )
        case .pushUpDepth:
            String(
                localized: "Lower your chest until your elbows reach about 90°, or do fewer reps you can take all the way down."
            )
        case .squatChestDrop:
            String(
                localized: "Keep your chest up: aim for a torso about as tilted as your shins."
            )
        case .squatDepth:
            String(
                localized: "If it feels comfortable, sit a little lower, toward knee height."
            )
        case .lungeTorsoLean:
            String(localized: "Stay tall: keep your shoulders over your hips as you lower.")
        case .lungeFrontKnee:
            String(
                localized: "Lower your back knee toward the floor until your front thigh is close to level."
            )
        case .deadliftKneeBend:
            String(
                localized: "Keep a slight, fixed bend in your knees and push your hips back instead."
            )
        case .deadliftHinge:
            String(
                localized: "Push your hips farther back and let your torso lower more, as far as feels comfortable."
            )
        }
    }

    /// A few words to show and say during the set, readable from a few steps away.
    var liveCue: String {
        switch self {
        case .pushUpHipsSag:
            String(localized: "Lift your hips")
        case .pushUpHipsPike:
            String(localized: "Lower your hips")
        case .pushUpDepth:
            String(localized: "Go lower")
        case .squatChestDrop:
            String(localized: "Chest up")
        case .squatDepth:
            String(localized: "Sit lower")
        case .lungeTorsoLean:
            String(localized: "Stay tall")
        case .lungeFrontKnee:
            String(localized: "Go lower")
        case .deadliftKneeBend:
            String(localized: "Straighter knees")
        case .deadliftHinge:
            String(localized: "Hips further back")
        }
    }

    var cueKind: CueKind {
        switch self {
        case .pushUpHipsSag:
            .pushUpHipsSag
        case .pushUpHipsPike:
            .pushUpHipsPike
        case .pushUpDepth:
            .pushUpDepth
        case .squatChestDrop:
            .squatChestDrop
        case .squatDepth:
            .squatDepth
        case .lungeTorsoLean:
            .lungeTorsoLean
        case .lungeFrontKnee:
            .lungeFrontKnee
        case .deadliftKneeBend:
            .deadliftKneeBend
        case .deadliftHinge:
            .deadliftHinge
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

    var observation: String {
        check.observation(reps: reps, typical: typical)
    }

    var cue: Cue {
        Cue(
            kind: check.cueKind,
            repNumbers: reps,
            earlierMedian: typical,
            laterMedian: typical,
            observation: observation,
            nextAction: check.nextAction
        )
    }
}

/// What the form checks found in one set: faults in advice order, and sentences for the result
/// (pull-up facts, secondary faults, and what Finn could not check and why).
nonisolated struct FormReview: Equatable, Sendable {
    var findings: [FormFinding] = []
    /// Every check supported by enough clear reps, including checks that found no fault.
    var measurements: [FormMeasurement] = []
    var notes: [String] = []
    /// Kept in memory so live catch-up cues can use only evidence available by that rep.
    var repReadings: [FormCheck: [FormRepReading]] = [:]

    func findings(through number: Int, exercise: ExerciseKind) -> [FormFinding] {
        var result: [FormFinding] = []
        for check in FormCheck.checks(for: exercise) {
            let readings = (repReadings[check] ?? []).filter { $0.number <= number }
            let faulty = readings.filter(\.isFault)
            guard
                readings.count * 2 >= number,
                faulty.count >= FormCheck.minimumFaultyReps,
                Double(faulty.count) >= FormCheck.minimumFaultyShare * Double(readings.count)
            else {
                continue
            }
            let values = faulty.map(\.value).sorted()
            result.append(FormFinding(
                check: check,
                reps: faulty.map(\.number),
                judged: readings.count,
                typical: values[values.count / 2]
            ))
        }
        if
            let sag = result.firstIndex(where: { $0.check == .pushUpHipsSag }),
            let pike = result.firstIndex(where: { $0.check == .pushUpHipsPike }) {
            result.remove(at: result[sag].reps.count >= result[pike].reps.count ? pike : sag)
        }
        return result
    }
}

nonisolated struct FormRepReading: Equatable, Sendable {
    let number: Int
    let value: Double
    let isFault: Bool
}

/// A compact, comparable measurement. The video and joint coordinates stay off disk.
nonisolated struct FormMeasurement: Codable, Equatable, Sendable {
    let check: FormCheck
    let judged: Int
    let faulty: Int
    let typical: Double
}

/// Facts measured on each rep of a set, beyond the count. For the squat, push-up, lunge and
/// stiff-leg deadlift, the coaching checks of `FormCheck`; for pull-ups and muscle-ups, whether the
/// chin passed the hands, whether the arms were straight at the start of the rep, and how much the
/// body swung. Each check is a camera measurement from the side, not a judgement of technique;
/// when a joint it needs is not tracked, it says so instead of guessing.
nonisolated enum FormChecks {
    /// A fault must last long enough to distinguish it from a brief landmark error.
    static let minimumFaultDuration: TimeInterval = 0.2
    static let maximumReadingGap: TimeInterval = 0.2
    static let bottomWindowRadius: TimeInterval = 0.15
    /// Elbow angle from which an arm counts as straight at the bottom of a pull-up.
    static let straightArmDegrees = 150.0
    /// Hip travel, forward and back, above which the body is said to swing (share of arm length).
    static let swingShare = 0.35

    static func sentences(
        for analysis: SetAnalysis,
        frames: [PoseFrame],
        definition: ExerciseDefinition
    ) -> [String] {
        review(analysis, frames: frames, definition: definition).notes
    }

    /// The checks of `definition`'s exercise over a measured set. `viewCheck` follows the person's
    /// camera-angle option: when it is on and Vision 3D saw the person at an angle, the side-view
    /// checks say nothing, since an angled view bends every 2D angle.
    static func review(
        _ analysis: SetAnalysis,
        frames: [PoseFrame],
        definition: ExerciseDefinition,
        viewCheck: ExerciseAnalyzer.ViewCheckPolicy = .enforce
    ) -> FormReview {
        guard
            PoseFrame.hasIncreasingTimestamps(frames), analysis.reps.allSatisfy(\.isValid),
            analysis.reps.enumerated().allSatisfy({ $0.element.number == $0.offset + 1 }) else {
            return FormReview()
        }
        switch definition.kind {
        case .pullUp,
             .muscleUp:
            return FormReview(notes: pullChecks(analysis, frames: frames, definition: definition))
        case .bodyweightSquat,
             .pushUp,
             .staticLunge,
             .stiffLegDeadlift:
            return sideChecks(analysis, frames: frames, definition: definition, viewCheck: viewCheck)
        }
    }

    // MARK: Side-view checks

    private static func sideChecks(
        _ analysis: SetAnalysis,
        frames: [PoseFrame],
        definition: ExerciseDefinition,
        viewCheck: ExerciseAnalyzer.ViewCheckPolicy
    ) -> FormReview {
        // push-ups counted from the shoulders (filmed from the front, or the arm out of the picture)
        // have no side-view joints to read; the result already says so.
        guard
            !analysis.reps.isEmpty,
            analysis.rubricVersion != ExerciseDefinition.pushUpShoulders.rubricVersion,
            analysis.rubricVersion != ExerciseDefinition.squatTrunk.rubricVersion,
            case .usable(let side) = EvidenceGate.assess(frames, requirement: definition.evidence) else {
            return FormReview()
        }
        if viewCheck == .enforce {
            switch ViewCheck.assess(frames, expected: .side) {
            case .angled(let deviation, _),
                 .mismatch(let deviation, _):
                // exercises filmed only from the side already get "turn a little" from the analysis.
                guard definition.expectedView == .any else {
                    return FormReview()
                }
                return FormReview(notes: [
                    String(
                        localized: "Finn checks \(definition.copy.shareNoun) form from the side only. It saw you about \(Int(deviation.rounded()))° from side-on, so it gives no form advice for this set."
                    ),
                ])
            case .matches,
                 .unavailable:
                break
            }
        }
        // All checks share the rep windows and angle assessment. Avoid scanning the full capture
        // again for each check; the windows are found with timestamp binary searches.
        let windows = analysis.reps.map { rep in
            let whole = Array(frames[ExerciseAnalyzer.frameRange(
                from: rep.startTime, through: rep.endTime, in: frames
            )])
            let bottom = bottomFrames(of: rep, in: frames, definition: definition, side: side)
            let supportsSide = viewCheck == .ignore || supportsSideMeasurements(whole[...])
            return (rep: rep, whole: whole, bottom: bottom, supportsSide: supportsSide)
        }
        let thigh = standingThigh(frames, side: side)
        var review = FormReview()
        for check in FormCheck.checks(for: definition.kind) {
            let readings = windows.compactMap { window -> FormRepReading? in
                guard window.supportsSide else {
                    return nil
                }
                let observed = check.needsBottomPosition ? window.bottom : window.whole
                return reading(check, rep: window.rep, frames: observed, side: side, standingThigh: thigh)
            }
            review.repReadings[check] = readings
            guard
                readings.count >= FormCheck.minimumFaultyReps,
                readings.count * 2 >= analysis.reps.count else {
                let observed = windows.flatMap { check.needsBottomPosition ? $0.bottom : $0.whole }
                review.notes.append(cannotCheck(check, frames: observed, side: side))
                continue
            }
            let faulty = readings.filter(\.isFault)
            review.measurements.append(FormMeasurement(
                check: check,
                judged: readings.count,
                faulty: faulty.count,
                typical: median(readings.map(\.value))
            ))
        }
        review.findings = review.findings(through: analysis.reps.count, exercise: definition.kind)
        // the first finding becomes the set's observation; the others are listed as facts.
        review.notes.insert(contentsOf: review.findings.dropFirst().map(\.observation), at: 0)
        return review
    }

    /// Depth checks use a short time window around the bottom. A fixed frame count changes its
    /// meaning when the camera slows down; timestamps keep the physical interval consistent.
    static func bottomFrames(
        of rep: RepMetric,
        in frames: [PoseFrame],
        definition: ExerciseDefinition,
        side: BodySide
    ) -> [PoseFrame] {
        guard
            let index = ExerciseAnalyzer.deepestFrameIndex(
                of: rep,
                in: frames,
                as: definition,
                side: side
            ) else {
            return []
        }
        let start = max(rep.startTime, frames[index].time - bottomWindowRadius)
        let end = min(rep.endTime, frames[index].time + bottomWindowRadius)
        return Array(frames[ExerciseAnalyzer.frameRange(from: start, through: end, in: frames)])
    }

    private static func reading(
        _ check: FormCheck,
        rep: RepMetric,
        frames: [PoseFrame],
        side: BodySide,
        standingThigh: Double?
    ) -> FormRepReading? {
        let readings = frames.compactMap { frame -> (time: TimeInterval, value: Double)? in
            guard
                let value = check.measure(frame, side: side, standingThigh: standingThigh),
                value.isFinite else {
                return nil
            }
            return (frame.time, value)
        }
        guard
            readings.count >= 3, readings.count * 2 > frames.count,
            let first = readings.first, let last = readings.last else {
            return nil
        }

        if check.needsBottomPosition {
            guard last.time - first.time >= 0.1 else {
                return nil
            }
            let visibleDuration = zip(readings, readings.dropFirst()).reduce(0.0) { total, pair in
                let gap = pair.1.time - pair.0.time
                return total + (gap <= maximumReadingGap + 0.000_001 ? gap : 0)
            }
            let windowDuration = (frames.last?.time ?? last.time) - (frames.first?.time ?? first.time)
            guard visibleDuration >= windowDuration * 0.6 else {
                return nil
            }
            let value = timeWeightedMedian(readings)
            return FormRepReading(number: rep.number, value: value, isFault: check.isFault(value))
        }

        var observedDuration = 0.0
        var runStart: Int?
        var sustained: Range<Int>?
        for index in readings.indices {
            let current = readings[index]
            let gap = index == 0 ? 0 : current.time - readings[index - 1].time
            if gap <= maximumReadingGap + 0.000_001 {
                observedDuration += gap
            } else {
                runStart = nil
            }
            guard check.isFault(current.value) else {
                runStart = nil
                continue
            }
            let start = runStart ?? index
            runStart = start
            let run = start ..< (index + 1)
            if run.count >= 3, current.time - readings[start].time + 0.000_001 >= minimumFaultDuration {
                // The longest supported episode represents the rep, not its single worst frame.
                let duration = current.time - readings[start].time
                let previousDuration = sustained
                    .map { readings[$0.upperBound - 1].time - readings[$0.lowerBound].time } ?? 0
                if duration > previousDuration {
                    sustained = run
                }
            }
        }
        guard observedDuration >= rep.duration * 0.6 else {
            return nil
        }
        let supported = sustained.map { Array(readings[$0]) } ?? readings
        return FormRepReading(
            number: rep.number,
            value: timeWeightedMedian(supported),
            isFault: sustained != nil
        )
    }

    /// Weight by observed time so a short burst of noisy frames cannot outvote a longer clear
    /// view. Missing intervals contribute no weight. This does not interpolate unseen poses.
    private static func timeWeightedMedian(_ readings: [(time: TimeInterval, value: Double)]) -> Double {
        let weighted = readings.indices.map { index -> (value: Double, weight: Double) in
            let before = index > 0 ? readings[index].time - readings[index - 1].time : 0
            let after = index + 1 < readings.count ? readings[index + 1].time - readings[index].time : 0
            let weight = (before <= maximumReadingGap + 0.000_001 ? before / 2 : 0)
                + (after <= maximumReadingGap + 0.000_001 ? after / 2 : 0)
            return (readings[index].value, weight)
        }.sorted { $0.value < $1.value }
        let halfway = weighted.reduce(0.0) { $0 + $1.weight } / 2
        guard halfway > 0 else {
            return median(readings.map(\.value))
        }
        var accumulated = 0.0
        for reading in weighted {
            accumulated += reading.weight
            if accumulated >= halfway {
                return reading.value
            }
        }
        return weighted.last?.value ?? 0
    }

    /// A set-wide median can hide the athlete turning for a few reps. Those reps must not
    /// become either faults or evidence of improvement. Older captures without 3D retain the
    /// existing 2D path; absence of an angle estimate is not proof of a side view.
    private static func supportsSideMeasurements(_ frames: ArraySlice<PoseFrame>) -> Bool {
        let estimates = frames.compactMap(\.profileDeviationDegrees)
        guard estimates.count >= 2 else {
            return true
        }
        return median(estimates) <= ViewCheck.maximumSideDeviationDegrees
    }

    /// The thigh's length over the set (its 90th percentile, the length seen standing).
    static func standingThigh(_ frames: [PoseFrame], side: BodySide) -> Double? {
        let lengths = frames.compactMap { BodySegments(frame: $0, side: side).thigh?.length }.sorted()
        guard lengths.count >= 5 else {
            return nil
        }
        return lengths[Int(Double(lengths.count - 1) * 0.9)]
    }

    /// Explain missing evidence from the same windows the check actually measured.
    private static func cannotCheck(_ check: FormCheck, frames: [PoseFrame], side: BodySide) -> String {
        if check == .lungeFrontKnee {
            let legSeen = frames.contains { frame in
                BodySegments(frame: frame, side: side).kneeAngle != nil
            }
            let frontSeen = frames.contains { check.measure($0, side: side) != nil }
            if legSeen && !frontSeen {
                return String(
                    localized: "Finn couldn’t check your front knee bend: it saw only your back leg clearly. Turn so your front leg is nearer the phone."
                )
            }
        }
        let weakest = check.joints.min { first, second in
            clearCount(first, in: frames, side: side, minimum: check.minimumConfidence)
                < clearCount(second, in: frames, side: side, minimum: check.minimumConfidence)
        } ?? check.joints[0]
        if clearCount(weakest, in: frames, side: side, minimum: check.minimumConfidence) * 2 > frames.count {
            return String(
                localized: "Finn couldn’t check your \(check.subject) from this camera position. Keep your side square to the phone."
            )
        }
        return String(
            localized: "Finn couldn’t check your \(check.subject): your \(weakest.localisedName.lowercased()) wasn’t clear enough during the reps."
        )
    }

    private static func clearCount(
        _ role: JointRole,
        in frames: [PoseFrame],
        side: BodySide,
        minimum: Double
    ) -> Int {
        frames.filter {
            $0.athleteVisible && ($0.joints[role.joint(on: side)]?.confidence ?? 0) >= minimum
        }.count
    }

    // MARK: Pull-ups and muscle-ups

    private static func pullChecks(
        _ analysis: SetAnalysis,
        frames: [PoseFrame],
        definition: ExerciseDefinition
    ) -> [String] {
        guard
            !analysis.reps.isEmpty,
            case .usable(let side) = EvidenceGate.assess(frames, requirement: definition.evidence)
        else {
            return []
        }
        var sentences: [String] = []
        let total = analysis.reps.count

        // chin above the hands at the top of each rep (the bar itself is not tracked).
        if definition.kind == .pullUp {
            let tops = analysis.reps.map { rep in
                ExerciseAnalyzer.deepestFrameIndex(of: rep, in: frames, as: definition, side: side)
                    .map { frames[$0] }
            }
            let judged = zip(analysis.reps, tops).compactMap { rep, frame -> (Int, Bool)? in
                guard let frame, let chin = chinAboveHands(frame) else {
                    return nil
                }
                return (rep.number, chin)
            }
            if judged.count * 2 >= total {
                let missed = judged.filter { !$0.1 }.map(\.0)
                sentences.append(missed.isEmpty
                    ? String(localized: "Chin above your hands in all \(judged.count) reps Finn could check.")
                    :
                    String(
                        localized: "Chin above your hands in \(judged.count - missed.count) of \(judged.count) reps; not in \(list(missed))."
                    ))
            }
        }

        // straight arms at the hang before each rep: the frame with the lowest shoulders between
        // the previous rep's end and this rep's start.
        let starts = analysis.reps.enumerated().compactMap { index, rep -> (Int, Double)? in
            let from = index == 0 ? (frames.first?.time ?? 0) : analysis.reps[index - 1].endTime
            let hang = frames[ExerciseAnalyzer.frameRange(
                from: from,
                through: rep.startTime + 0.05,
                in: frames
            )]
            .compactMap { frame -> (PoseFrame, Double)? in
                guard
                    let shoulder = frame.joints[JointRole.shoulder.joint(on: side)],
                    shoulder.confidence >= EvidenceRubric.minimumJointConfidence else {
                    return nil
                }
                return (frame, shoulder.y)
            }
            .max { $0.1 < $1.1 }?.0
            return hang.flatMap { elbowAngle($0, side: side) }.map { (rep.number, $0) }
        }
        if starts.count * 2 >= total {
            let bent = starts.filter { $0.1 < straightArmDegrees }.map(\.0)
            sentences.append(bent.isEmpty
                ? String(localized: "Arms straight at the start of every rep.")
                : String(localized: "Arms not fully straight at the start of \(list(bent))."))
        }

        // swing: how far the hips travel forward and back during the set.
        if let swing = swing(frames, side: side), swing >= swingShare {
            sentences
                .append(
                    String(
                        localized: "Your hips swung about \(Int((swing * 100).rounded()))% of your arm length forward and back. A still body makes each rep count the same."
                    )
                )
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
        guard let hands = wrists.map(\.y).min() else {
            return nil
        }
        return nose.y < hands
    }

    private static func elbowAngle(_ frame: PoseFrame, side: BodySide) -> Double? {
        BodySegments(frame: frame, side: side, minimumConfidence: EvidenceRubric.minimumJointConfidence)
            .elbowAngle
    }

    /// Spread of hip position across the set (10th to 90th percentile), over the arm length.
    private static func swing(_ frames: [PoseFrame], side: BodySide) -> Double? {
        let points = frames.compactMap { frame -> (hipX: Double, arm: Double)? in
            guard
                let hip = frame.joints[JointRole.hip.joint(on: side)],
                let shoulder = frame.joints[JointRole.shoulder.joint(on: side)],
                let wrist = frame.joints[JointRole.wrist.joint(on: side)],
                min(hip.confidence, shoulder.confidence, wrist.confidence) >= EvidenceRubric
                    .minimumJointConfidence
            else {
                return nil
            }
            let arm = hypot(shoulder.x - wrist.x, (shoulder.y - wrist.y) * frame.aspectRatio)
            return (hip.x, arm)
        }
        guard points.count >= 10 else {
            return nil
        }
        let xs = points.map(\.hipX).sorted()
        let arms = points.map(\.arm).sorted()
        let arm = arms[Int(Double(arms.count - 1) * 0.9)]
        guard arm > 0 else {
            return nil
        }
        return (xs[Int(Double(xs.count - 1) * 0.9)] - xs[Int(Double(xs.count - 1) * 0.1)]) / arm
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    /// "rep 2", "rep 2 and rep 5", "rep 2, rep 3 and rep 5".
    static func list(_ reps: [Int]) -> String {
        let names = reps.map { String(localized: "rep \($0)") }
        guard let last = names.last, names.count > 1 else {
            return names.first ?? ""
        }
        return String(localized: "\(names.dropLast().joined(separator: ", ")) and \(last)")
    }
}
