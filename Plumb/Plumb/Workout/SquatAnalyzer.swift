import Foundation

nonisolated enum SquatRubric {
    /// v3 (12 October 2026): evidence floor 0.3 instead of 0.6, robust still-joint check, and the
    /// top position taken from the whole set instead of its first frames. v2 refused all 50 real
    /// side-view squat videos it was tried on.
    /// v4 (12 October 2026): follows one athlete, so other people in view no longer refuse the
    /// set, and the athlete may be hidden by someone else for up to 3 s (see `EvidenceRubric`).
    /// v5 (13 October 2026): camera capture corroborates joints with a person mask so an ankle
    /// inferred behind an obstruction cannot make a set appear measurable.
    /// v6 (13 October 2026, main): adds an optional torso-tilt reading at the bottom of each rep.
    /// v7 (13 October 2026): v6 plus measuring only the set, not the walk to the spot and back to the
    /// phone (`SetWindow`), a person-mask search in proportion to the body that ignores an empty mask
    /// (`SilhouetteCheck`), and a rep's deepest point kept after a wobble. v5 refused real sets.
    static let version = "squat-side-v7"
    static let minimumJointConfidence = EvidenceRubric.minimumJointConfidence
    static let descentThreshold = 0.10
    /// v3: 0.05 (was 0.03), about twice Vision's hip jitter on real side-view video
    static let completionThreshold = 0.05
    static let ascentFromPeakThreshold = 0.04
    static let minimumHipTravel = 0.15
    /// v3: 0.5 s (was 0.8). A rep now ends once the person is 65% of the way back up, which
    /// shortens its measured time; at 0.8 s, real one-second squats were dropped as too fast.
    static let minimumRepDuration = 0.5
    static let maximumRepDuration = 8.0
    static let maximumTrackingGap = EvidenceRubric.maximumTrackingGap
    static let maximumBystanderDuration = EvidenceRubric.maximumBystanderDuration
}

/// the side-view squat, now one entry in `ExerciseDefinition`. Kept for existing callers.
nonisolated enum SquatAnalyzer {
    static func analyze(_ frames: [PoseFrame]) -> AnalysisOutcome {
        ExerciseAnalyzer.analyze(frames, as: .squat)
    }
}

/// counts reps for any `ExerciseDefinition` with one state machine over a single movement signal:
/// top phase → leaving the top → bottom reached → back at the top. It abstains instead of guessing
/// when the evidence gate rejects the view or the signal joints are not tracked.
nonisolated enum ExerciseAnalyzer {
    /// a rep also ends once the person has come back up by 65% of that rep's own depth, so
    /// continuous reps without a full stand still count. Checked against real side-view squats:
    /// at 35% the counts matched an independent dip count; at 45% reps were counted twice.
    /// The next rep is then measured from wherever the person tops out, never from the end of this one.
    static let repEndShareOfDepth = 0.35
    /// a movement that came back up by this share of its depth and then goes down again (by the
    /// exercise's `leaveTop`) is over at the turn, without counting; the next one starts there.
    /// Below it, the rise is a stall on the way down and the rep goes on.
    static let turnShareOfDepth = 0.6

    /// whether 3D camera-angle estimates in the frames may reject the set
    enum ViewCheckPolicy: Equatable {
        case enforce
        case ignore
    }

    private enum Phase {
        case top
        case descending(start: TimeInterval, peak: Double, peakIndex: Int)
        /// `rise`: the highest point (least travel) reached on the way up so far
        case ascending(start: TimeInterval, peak: Double, peakIndex: Int, rise: Double, riseTime: TimeInterval)
    }

    private struct Sample {
        let time: TimeInterval
        /// joint height for vertical travel or rise, joint angle in degrees for a bend
        let value: Double
        /// reference height for vertical travel, joint-to-reference distance for a rise, shortest
        /// limb segment for a bend.
        let scale: Double
        let confidence: Double
        let posture: Double?
    }

    static func analyze(_ frames: [PoseFrame], as definition: ExerciseDefinition,
                        viewCheck: ViewCheckPolicy = .enforce) -> AnalysisOutcome {
        analyzeWithDiagnostics(frames, as: definition, viewCheck: viewCheck).outcome
    }

    /// the analysis plus what the movement looked like, so the result can say why a movement
    /// did not count instead of staying silent.
    /// `trimsToSet` keeps only the set itself (`SetWindow`); pass false for frames already trimmed.
    static func analyzeWithDiagnostics(_ frames: [PoseFrame], as definition: ExerciseDefinition,
                                       viewCheck: ViewCheckPolicy = .enforce, trimsToSet: Bool = true)
        -> (outcome: AnalysisOutcome, diagnostics: MovementDiagnostics?) {
        // walking to the spot and back to the phone is not part of the set, for either count: the
        // replay tool then gives what the iPhone gives, which trims before calling.
        let frames = trimsToSet ? SetWindow.active(frames, requirement: definition.evidence) : frames
        let sideView = analyzeSideView(frames, as: definition, viewCheck: viewCheck)
        // the push-up rubric reads the elbow, which needs a side view with the whole arm in the
        // picture. Filmed from the front, or close enough to cut the arm off, the shoulders still
        // show how many times the person went down. The squat rubric reads the hip against the
        // ankle on one side; with the phone low, the feet at the picture's edge, the athlete turning
        // or stepping out of view for a moment, the hips still show each rep. The trunk is used when
        // the rubric refused the set, found nothing, or counted only the reps it could see in a
        // partly visible set. On 15 October a set refused once stayed refused: the live count froze
        // at 3 while the athlete squatted on.
        let trunkCount: (([PoseFrame]) -> (outcome: AnalysisOutcome, diagnostics: MovementDiagnostics?)?)?
        switch definition {
        case .pushUp: trunkCount = analyzeShoulders
        case .squat: trunkCount = analyzeHips
        default: trunkCount = nil
        }
        guard let trunkCount else { return sideView }
        var sideReps = 0
        if case .analyzed(let analysis) = sideView.outcome {
            sideReps = analysis.reps.count
            if sideReps > 0, sideView.diagnostics?.partialVisibility == nil { return sideView }
        }
        guard let fromTrunk = trunkCount(frames), case .analyzed(let counted) = fromTrunk.outcome,
              counted.reps.count > sideReps else {
            return sideView
        }
        return fromTrunk
    }

    private static func analyzeSideView(_ frames: [PoseFrame], as definition: ExerciseDefinition,
                                        viewCheck: ViewCheckPolicy)
        -> (outcome: AnalysisOutcome, diagnostics: MovementDiagnostics?) {
        let side: BodySide
        // a set whose joints were clear in 65 to 80% of it is measured from its clear reps only
        var partial: PartialVisibility?
        switch EvidenceGate.assess(frames, requirement: definition.evidence) {
        case .usable(let acceptedSide): side = acceptedSide
        case .reject(let reason):
            let refusal = EvidenceGate.explanation(for: reason, frames: frames, requirement: definition.evidence)
            guard let visibility = EvidenceGate.partialVisibility(frames, requirement: definition.evidence),
                  case .usable(let partlySeenSide) = EvidenceGate.assess(
                    frames, requirement: definition.evidence, allowsPartial: true) else {
                return (.insufficientView(refusal), nil)
            }
            side = partlySeenSide
            partial = visibility
        }
        // without 3D estimates (simulator, older devices, switched off) this check does not run.
        // Only a clearly frontal view held for several seconds refuses the set; an angled one is
        // measured and the result suggests turning a little.
        var angledView: Double?
        // push-ups are accepted from any view, but hip sag is a side-view measure: from the front
        // or at an angle the count stands and the posture advice is left out, with no tip to turn.
        var postureFromSide = true
        if viewCheck == .enforce, definition.kind == .pushUp, definition.expectedView == .any {
            switch ViewCheck.assess(frames, expected: .side) {
            case .angled, .mismatch: postureFromSide = false
            case .matches, .unavailable: break
            }
        }
        // a front view no longer refuses the set: hip travel reads the same from the front, and a
        // jury trying the app faces the phone. Only the posture advice, a side-view measure, is left out.
        if viewCheck == .enforce {
            switch ViewCheck.assess(frames, expected: definition.expectedView) {
            case .angled(let deviation, _), .mismatch(let deviation, _):
                angledView = deviation
            case .matches, .unavailable:
                break
            }
        }

        let samples = frames.compactMap { sample(from: $0, as: definition, side: side) }
        return countReps(samples, in: frames, as: definition, side: side, partial: partial, angledView: angledView,
                         postureFromSide: postureFromSide)
    }

    /// the rep state machine, shared by the side-view rubric and the front-view count.
    /// `restartAfterGap`: a stretch without samples longer than this ends any rep under way, and
    /// the next one is measured from where the person is seen again. Nil bridges every gap, for
    /// rubrics whose evidence gate already refused long ones.
    private static func countReps(_ samples: [Sample], in frames: [PoseFrame], as definition: ExerciseDefinition,
                                  side: BodySide, partial: PartialVisibility?, angledView: Double?,
                                  postureFromSide: Bool = true, restartAfterGap: TimeInterval? = nil)
        -> (outcome: AnalysisOutcome, diagnostics: MovementDiagnostics?) {
        guard samples.count >= 5 else {
            return (.insufficientView(definition.copy.keepJointsVisible), nil)
        }

        // the top of the movement is where the person spends the set's highest (squat) or most
        // open (bend) moments, measured over the whole set rather than its first frames.
        let baseline: Double
        let travel: (Double) -> Double
        switch definition.signal {
        case .verticalTravel:
            baseline = percentile(samples.map(\.value), 0.1)
            let standingLength = median(samples.map(\.scale)) - baseline
            guard standingLength > definition.minimumBodyScale else {
                return (.insufficientView(definition.copy.bodyTooSmall), nil)
            }
            travel = { max(0, ($0 - baseline) / standingLength) }
        case .verticalRise:
            // the rest position is the hang: shoulders at their lowest, an arm's length below the
            // hands. The hands hold the bar, so their height is one value for the set; the frames
            // where Vision misses them (often, with the bar near the top of the picture) still count.
            baseline = percentile(samples.map(\.value), 0.9)
            let hands = samples.map(\.scale).filter { !$0.isNaN }
            guard hands.count >= 3 else { return (.insufficientView(definition.copy.keepJointsVisible), nil) }
            let armLength = baseline - median(hands)
            guard armLength > definition.minimumBodyScale else {
                return (.insufficientView(definition.copy.bodyTooSmall), nil)
            }
            travel = { max(0, (baseline - $0) / armLength) }
        case .jointBend:
            baseline = percentile(samples.map(\.value), 0.9)
            guard median(samples.map(\.scale)) > definition.minimumBodyScale else {
                return (.insufficientView(definition.copy.bodyTooSmall), nil)
            }
            travel = { max(0, baseline - $0) }
        case .shoulderDrop:
            // the top is where the shoulders sit highest. A set that barely moves them (a person
            // standing, or Vision's jitter) never reaches the amplitude of a squat.
            baseline = percentile(samples.map(\.value), 0.1)
            guard percentile(samples.map(\.value), 0.9) - baseline > definition.minimumBodyScale else {
                return (.insufficientView(definition.copy.keepJointsVisible), nil)
            }
            travel = { max(0, $0 - baseline) }
        }

        let smoothed = samples.indices.map { index -> Double in
            let lower = max(0, index - 1)
            let upper = min(samples.count - 1, index + 1)
            let window = samples[lower...upper]
            return window.map(\.value).reduce(0, +) / Double(window.count)
        }

        let phases = definition.phases
        var phase: Phase = .top
        // every threshold is measured from the local top: the highest (most open) point since the
        // previous rep ended. In a run of continuous reps the person may not come all the way back
        // to the set's top, and on a real phone that top drifts by a few percent during a set.
        // A set that opens partway down a rep (it started during the countdown) measures that first
        // rep from the set's top, so its depth is not cut short.
        var localTop = travel(smoothed[0]) > phases.backAtTop ? 0 : Double.infinity
        var lastTopTime = samples[0].time
        var reps: [RepMetric] = []
        var diagnostics = MovementDiagnostics(requiredDepth: phases.reachBottom, angledView: angledView)
        for (index, sample) in samples.enumerated() {
            let distance = travel(smoothed[index])
            if let restartAfterGap, index > 0, sample.time - samples[index - 1].time > restartAfterGap {
                // the athlete was out of view: what they did meanwhile is unknown
                phase = .top
                localTop = distance
                lastTopTime = sample.time
            }
            switch phase {
            case .top:
                if distance <= localTop + phases.backAtTop {
                    lastTopTime = sample.time
                }
                localTop = min(localTop, distance)
                diagnostics.deepest = max(diagnostics.deepest, distance - localTop)
                if distance - localTop >= phases.leaveTop {
                    phase = .descending(start: lastTopTime, peak: distance, peakIndex: index)
                }
            case .descending(let start, let peak, let peakIndex):
                let updatedPeak = max(peak, distance)
                let updatedPeakIndex = distance > peak ? index : peakIndex
                diagnostics.deepest = max(diagnostics.deepest, updatedPeak - localTop)
                if updatedPeak - localTop >= phases.reachBottom &&
                    updatedPeak - distance >= phases.returnFromBottom {
                    phase = .ascending(start: start, peak: updatedPeak, peakIndex: updatedPeakIndex,
                                       rise: distance, riseTime: sample.time)
                } else if distance <= localTop + phases.backAtTop {
                    // came back up without reaching the bottom: a shallow movement
                    diagnostics.shallow += 1
                    diagnostics.deepestShallow = max(diagnostics.deepestShallow, updatedPeak - localTop)
                    lastTopTime = sample.time
                    localTop = distance
                    phase = .top
                } else {
                    phase = .descending(start: start, peak: updatedPeak, peakIndex: updatedPeakIndex)
                }
            case .ascending(let start, let lastPeak, let lastPeakIndex, let lastRise, let lastRiseTime):
                // a pause or wobble on the way down can look like the way up; the rep's depth is
                // still its deepest point, and its posture is read there.
                let peak = max(lastPeak, distance)
                let peakIndex = distance > lastPeak ? index : lastPeakIndex
                let depth = peak - localTop
                let rise = min(lastRise, distance)
                let riseTime = distance < lastRise ? sample.time : lastRiseTime
                if distance <= localTop + max(phases.backAtTop, depth * repEndShareOfDepth) {
                    let duration = sample.time - start
                    if (phases.minimumDuration...phases.maximumDuration).contains(duration) {
                        let nearby = samples[max(0, peakIndex - 2)...min(samples.count - 1, peakIndex + 2)]
                            .compactMap(\.posture)
                        reps.append(RepMetric(
                            number: reps.count + 1,
                            startTime: start,
                            endTime: sample.time,
                            relativeRange: depth,
                            postureValue: angledView == nil && postureFromSide && nearby.count >= 3 ? median(nearby) : nil
                        ))
                    } else {
                        diagnostics.outsideTempo += 1
                    }
                    lastTopTime = sample.time
                    localTop = distance
                    phase = .top
                } else if peak - rise >= depth * turnShareOfDepth, distance - rise >= phases.leaveTop {
                    // came most of the way back up, then went down again by a rep's opening travel
                    // before reaching the top: the movement so far did not come back, so it is not
                    // a rep, and the next one is measured from where the person turned. Before,
                    // the rep stayed open and every later dip merged into it: twelve fast push-ups
                    // whose tops sat below the opening plank gave one 6.7 s rep (15 October). A
                    // stall with a small rise on the way down comes back up less than this share
                    // and still deepens the same rep.
                    diagnostics.incomplete += 1
                    lastTopTime = riseTime
                    localTop = rise
                    phase = .descending(start: riseTime, peak: distance, peakIndex: index)
                } else {
                    phase = .ascending(start: start, peak: peak, peakIndex: peakIndex, rise: rise, riseTime: riseTime)
                }
            }
        }
        if case .top = phase {} else { diagnostics.unfinished = true }

        if let partial {
            // only reps whose own frames show the joints often enough count; they are numbered again
            let clear = reps.filter {
                EvidenceGate.isClear(frames, requirement: definition.evidence, side: side,
                                     from: $0.startTime, to: $0.endTime)
            }
            guard !clear.isEmpty else {
                return (.insufficientView(EvidenceGate.explanation(
                    for: .missingJoints, frames: frames, requirement: definition.evidence)), nil)
            }
            diagnostics.partialVisibility = partial
            diagnostics.unclearReps = reps.count - clear.count
            reps = clear.enumerated().map { index, rep in
                RepMetric(number: index + 1, startTime: rep.startTime, endTime: rep.endTime,
                          relativeRange: rep.relativeRange, postureValue: rep.postureValue)
            }
        }

        let confidence = samples.map(\.confidence).reduce(0, +) / Double(samples.count)
        return (.analyzed(SetAnalysis(reps: reps, confidence: confidence,
                                      rubricVersion: definition.rubricVersion)), diagnostics)
    }

    // MARK: Shoulders only

    /// a shoulder gap is read as a hidden bottom when both of its ends are at least this share of
    /// the seen travel below the top, and filled down to this share of it.
    private static let hiddenBottomEntry = 0.25
    private static let hiddenBottomDepth = 0.8

    /// counts a push-up from the shoulders going down and up. Nil when the set is too short, the
    /// shoulders (or the nose standing in for them) are seen in too few frames, the hands do not
    /// stay planted, or no rep is found: the arm rubric's refusal then stays, because it explains more.
    /// Depth and posture are not measured from here, so the result carries no posture advice.
    private static func analyzeShoulders(_ frames: [PoseFrame])
        -> (outcome: AnalysisOutcome, diagnostics: MovementDiagnostics?)? {
        guard let first = frames.first, let last = frames.last,
              last.time - first.time >= EvidenceRubric.minimumSetDuration,
              !EvidenceGate.isCrowded(frames) else { return nil }
        let samples = shoulderSamples(frames)
        guard Double(samples.count) / Double(frames.count) >= EvidenceRubric.partialCoverage else { return nil }
        let values = samples.map(\.value)
        let travel = percentile(values, 0.9) - percentile(values, 0.1)
        var definition = ExerciseDefinition.pushUpShoulders
        guard travel > definition.minimumBodyScale, handsStayPlanted(frames, shoulderTravel: travel) else { return nil }
        // a push-up is the same movement a metre or four metres from the phone, only smaller in the
        // picture: the rep phases follow the set's own travel.
        definition = definition.withPhases(RepPhases(
            leaveTop: travel * 0.2, reachBottom: travel * 0.55, returnFromBottom: travel * 0.15,
            backAtTop: travel * 0.2, minimumDuration: definition.phases.minimumDuration,
            maximumDuration: definition.phases.maximumDuration))
        let result = countReps(samples, in: frames, as: definition, side: .left, partial: nil, angledView: nil)
        guard case .analyzed(let analysis) = result.outcome, !analysis.reps.isEmpty else { return nil }
        var diagnostics = result.diagnostics ?? MovementDiagnostics(requiredDepth: definition.phases.reachBottom)
        diagnostics.countedFromShoulders = true
        return (result.outcome, diagnostics)
    }

    // MARK: Hips only

    /// a gap longer than this in the hips (and the shoulders standing in for them) restarts the rep
    /// count: the athlete stepped out of the picture or Vision lost them.
    static let hipGapRestart: TimeInterval = 1.0
    /// a torso this much longer than the set's usual one is the athlete close to the phone, walking
    /// to it or reaching for it, not a squat.
    static let closeToPhoneTorso = 1.4

    /// counts squats from the hips going down and up (`ExerciseDefinition.squatTrunk`). Nil when the
    /// set is too short, someone else's joints cannot be told apart, the torso is never seen to set
    /// the scale, the hips travel less than a shallow squat, or no rep is found: the side rubric's
    /// refusal then stays, because it explains more. No coverage share is required: reps done
    /// while the athlete is seen count, a stretch out of view does not cancel them.
    /// Depth is measured in torso lengths, posture not at all: the result carries no posture advice.
    private static func analyzeHips(_ frames: [PoseFrame])
        -> (outcome: AnalysisOutcome, diagnostics: MovementDiagnostics?)? {
        guard let first = frames.first, let last = frames.last,
              last.time - first.time >= EvidenceRubric.minimumSetDuration,
              !EvidenceGate.isCrowded(frames) else { return nil }
        let samples = hipSamples(frames)
        guard samples.count >= 5 else { return nil }
        let values = samples.map(\.value)
        let travel = percentile(values, 0.9) - percentile(values, 0.1)
        var definition = ExerciseDefinition.squatTrunk
        guard travel > definition.minimumBodyScale else { return nil }
        // the same squat is a larger share of the torso seen from below than from the side: the
        // phases follow the set's own travel, never under the definition's floor.
        let floor = definition.phases
        definition = definition.withPhases(RepPhases(
            leaveTop: max(floor.leaveTop, travel * 0.2), reachBottom: max(floor.reachBottom, travel * 0.5),
            returnFromBottom: max(floor.returnFromBottom, travel * 0.15),
            backAtTop: max(floor.backAtTop, travel * 0.2),
            minimumDuration: floor.minimumDuration, maximumDuration: floor.maximumDuration))
        let result = countReps(samples, in: frames, as: definition, side: .left, partial: nil, angledView: nil,
                               postureFromSide: false, restartAfterGap: hipGapRestart)
        guard case .analyzed(let analysis) = result.outcome, !analysis.reps.isEmpty else { return nil }
        var diagnostics = result.diagnostics ?? MovementDiagnostics(requiredDepth: definition.phases.reachBottom)
        diagnostics.countedFromHips = true
        return (result.outcome, diagnostics)
    }

    /// height of the hips (the midpoint of those Vision sees clearly, either side), in torso lengths,
    /// per frame where the athlete is seen. When both hips are lost, the shoulders stand in at their
    /// usual distance above them. The torso length is the set's median distance from the shoulders'
    /// midpoint to the hips'; frames where it is much longer (the athlete at the phone) are left out.
    /// Empty when the torso is never seen, so the scale is unknown.
    private static func hipSamples(_ frames: [PoseFrame]) -> [Sample] {
        func centre(_ frame: PoseFrame, _ role: JointRole) -> (x: Double, y: Double, confidence: Double)? {
            let points = [BodySide.left, .right].compactMap { side -> JointPoint? in
                frame.joints[role.joint(on: side)].flatMap {
                    $0.confidence >= EvidenceRubric.minimumJointConfidence ? $0 : nil
                }
            }
            guard !points.isEmpty else { return nil }
            let count = Double(points.count)
            return (points.map(\.x).reduce(0, +) / count,
                    points.map(\.y).reduce(0, +) / count * frame.aspectRatio,
                    points.map(\.confidence).min() ?? 0)
        }
        struct Reading {
            let time: TimeInterval
            let hip: (x: Double, y: Double, confidence: Double)?
            let shoulder: (x: Double, y: Double, confidence: Double)?
            var torso: Double? {
                guard let hip, let shoulder else { return nil }
                return hypot(hip.x - shoulder.x, hip.y - shoulder.y)
            }
        }
        let readings = frames.filter(\.athleteVisible).map {
            Reading(time: $0.time, hip: centre($0, .hip), shoulder: centre($0, .shoulder))
        }
        let torsos = readings.compactMap(\.torso).filter { $0 > 0 }
        guard torsos.count >= 3 else { return [] }
        let torso = median(torsos)
        let offsets = readings.compactMap { reading in
            reading.hip.flatMap { hip in reading.shoulder.map { hip.y - $0.y } }
        }
        let shoulderOffset = median(offsets)
        return readings.compactMap { reading -> Sample? in
            if let length = reading.torso, length > closeToPhoneTorso * torso { return nil }
            let height: Double
            let confidence: Double
            if let hip = reading.hip {
                height = hip.y
                confidence = hip.confidence
            } else if let shoulder = reading.shoulder {
                height = shoulder.y + shoulderOffset
                confidence = shoulder.confidence
            } else {
                return nil
            }
            return Sample(time: reading.time, value: height / torso, scale: 0, confidence: confidence, posture: nil)
        }
    }

    /// a push-up keeps the hands on the floor while the shoulders travel. A person squatting or
    /// jumping about moves the wrists about as much as the shoulders, and is not counted. Seen in
    /// at least a quarter of the frames, the wrists' middle half of heights must span under a third
    /// of the shoulders' travel.
    private static func handsStayPlanted(_ frames: [PoseFrame], shoulderTravel: Double) -> Bool {
        let heights = frames.compactMap { frame -> Double? in
            let wrists = [BodyJoint.leftWrist, .rightWrist].compactMap { joint in
                frame.joints[joint].flatMap { $0.confidence >= EvidenceRubric.minimumJointConfidence ? $0.y : nil }
            }
            return wrists.isEmpty ? nil : wrists.reduce(0, +) / Double(wrists.count) * frame.aspectRatio
        }
        guard Double(heights.count) / Double(frames.count) >= 0.25 else { return false }
        return percentile(heights, 0.75) - percentile(heights, 0.25) < shoulderTravel / 3
    }

    /// height of the shoulders (their midpoint, in image-width units so the scale does not depend on
    /// the picture's shape), per frame. When Vision loses both shoulders, the nose stands in at its
    /// usual distance above them; a gap of at most `EvidenceRubric.maximumTrackingGap` is bridged,
    /// as the rep passes through it. Longer gaps stay empty. Vision loses the shoulders at the
    /// bottom of a push-up, where the head leaves the picture or the arms hide them, so a gap that
    /// starts and ends well below the top is filled with a dip toward the deepest seen position
    /// instead of a straight line, which would flatten the rep out of existence.
    private static func shoulderSamples(_ frames: [PoseFrame]) -> [Sample] {
        func clear(_ frame: PoseFrame, _ joint: BodyJoint) -> JointPoint? {
            frame.joints[joint].flatMap { $0.confidence >= EvidenceRubric.minimumJointConfidence ? $0 : nil }
        }
        struct Reading { let value: Double?; let nose: Double?; let confidence: Double }
        let readings = frames.map { frame -> Reading in
            let shoulders = [clear(frame, .leftShoulder), clear(frame, .rightShoulder)].compactMap { $0 }
            let nose = clear(frame, .nose)
            return Reading(
                value: shoulders.isEmpty ? nil
                    : shoulders.map(\.y).reduce(0, +) / Double(shoulders.count) * frame.aspectRatio,
                nose: nose.map { $0.y * frame.aspectRatio },
                confidence: (shoulders.map(\.confidence) + [nose?.confidence].compactMap { $0 }).min() ?? 0)
        }
        let offsets = readings.compactMap { reading in
            reading.value.flatMap { value in reading.nose.map { value - $0 } }
        }
        let noseOffset = offsets.isEmpty ? nil : median(offsets)
        var heights: [Double?] = readings.map { reading in
            reading.value ?? noseOffset.flatMap { offset in reading.nose.map { $0 + offset } }
        }
        let known = heights.indices.filter { heights[$0] != nil }
        let seen = heights.compactMap { $0 }
        let top = seen.isEmpty ? 0 : percentile(seen, 0.1)
        let reach = seen.isEmpty ? 0 : percentile(seen, 0.9) - top
        for (before, after) in zip(known, known.dropFirst()) where after > before + 1 {
            let span = frames[after].time - frames[before].time
            guard span <= EvidenceRubric.maximumTrackingGap,
                  let start = heights[before], let end = heights[after] else { continue }
            let hiddenBottom = reach > ExerciseDefinition.pushUpShoulders.minimumBodyScale
                && min(start, end) - top >= reach * hiddenBottomEntry
            for index in (before + 1)..<after {
                let share = (frames[index].time - frames[before].time) / span
                let line = start + (end - start) * share
                heights[index] = hiddenBottom
                    ? line + max(0, top + reach * hiddenBottomDepth - line) * sin(.pi * share)
                    : line
            }
        }
        return frames.indices.compactMap { index in
            heights[index].map {
                Sample(time: frames[index].time, value: $0, scale: 0,
                       confidence: max(readings[index].confidence, EvidenceRubric.minimumJointConfidence),
                       posture: nil)
            }
        }
    }

    /// the frame where a rep went deepest (hips lowest, or the joint most bent), to draw it
    static func deepestFrame(of rep: RepMetric, in frames: [PoseFrame],
                             as definition: ExerciseDefinition) -> PoseFrame? {
        guard case .usable(let side) = EvidenceGate.assess(frames, requirement: definition.evidence,
                                                            allowsPartial: true) else {
            return nil
        }
        let candidates = frames.filter { $0.time >= rep.startTime && $0.time <= rep.endTime }
            .compactMap { frame in sample(from: frame, as: definition, side: side).map { (frame, $0.value) } }
        switch definition.signal {
        case .verticalTravel: return candidates.max { $0.1 < $1.1 }?.0
        case .jointBend, .verticalRise: return candidates.min { $0.1 < $1.1 }?.0
        case .shoulderDrop: return candidates.max { $0.1 < $1.1 }?.0
        }
    }

    /// angle at `vertex` in degrees, with y scaled by the image aspect ratio so it matches x
    static func angle(from a: JointPoint, vertex b: JointPoint, to c: JointPoint,
                      aspectRatio: Double) -> Double? {
        let first = (x: a.x - b.x, y: (a.y - b.y) * aspectRatio)
        let second = (x: c.x - b.x, y: (c.y - b.y) * aspectRatio)
        let firstLength = hypot(first.x, first.y)
        let secondLength = hypot(second.x, second.y)
        guard firstLength > 0, secondLength > 0 else { return nil }
        let cosine = (first.x * second.x + first.y * second.y) / (firstLength * secondLength)
        return acos(min(1, max(-1, cosine))) * 180 / .pi
    }

    private static func confidentPoint(_ role: JointRole, in frame: PoseFrame,
                                       side: BodySide) -> JointPoint? {
        guard let point = frame.joints[role.joint(on: side)],
              point.confidence >= EvidenceRubric.minimumJointConfidence else { return nil }
        return point
    }

    private static func sample(from frame: PoseFrame, as definition: ExerciseDefinition,
                               side: BodySide) -> Sample? {
        let posture = postureValue(in: frame, exercise: definition.kind, side: side)
        switch definition.signal {
        case .verticalTravel(let jointRole, let referenceRole):
            guard let joint = confidentPoint(jointRole, in: frame, side: side),
                  let reference = confidentPoint(referenceRole, in: frame, side: side) else { return nil }
            return Sample(time: frame.time, value: joint.y, scale: reference.y,
                          confidence: min(joint.confidence, reference.confidence), posture: posture)
        case .verticalRise(let jointRole, let referenceRole):
            // the reference (the hands on the bar) is optional per frame: `scale` holds its height or NaN
            guard let joint = confidentPoint(jointRole, in: frame, side: side) else { return nil }
            let reference = confidentPoint(referenceRole, in: frame, side: side)
                ?? confidentPoint(referenceRole, in: frame, side: side == .left ? .right : .left)
            return Sample(time: frame.time, value: joint.y, scale: reference?.y ?? .nan,
                          confidence: joint.confidence, posture: posture)
        case .shoulderDrop:
            // built over the whole set by `shoulderSamples`: it needs the nose offset and the gaps
            return nil
        case .jointBend(let fromRole, let vertexRole, let toRole):
            guard let from = confidentPoint(fromRole, in: frame, side: side),
                  let vertex = confidentPoint(vertexRole, in: frame, side: side),
                  let to = confidentPoint(toRole, in: frame, side: side),
                  let angle = angle(from: from, vertex: vertex, to: to,
                                    aspectRatio: frame.aspectRatio) else { return nil }
            let firstSegment = hypot(from.x - vertex.x, (from.y - vertex.y) * frame.aspectRatio)
            let secondSegment = hypot(to.x - vertex.x, (to.y - vertex.y) * frame.aspectRatio)
            return Sample(time: frame.time, value: angle, scale: min(firstSegment, secondSegment),
                          confidence: min(from.confidence, vertex.confidence, to.confidence), posture: posture)
        }
    }

    /// one camera-visible posture signal at a rep's deepest phase. Supporting joints need a
    /// higher confidence than the rep signal; a missing joint leaves the reading unavailable.
    private static func postureValue(in frame: PoseFrame, exercise: ExerciseKind,
                                     side: BodySide) -> Double? {
        func point(_ role: JointRole) -> JointPoint? {
            guard let value = frame.joints[role.joint(on: side)], value.confidence >= 0.5 else { return nil }
            return value
        }
        switch exercise {
        case .bodyweightSquat, .staticLunge:
            guard let shoulder = point(.shoulder), let hip = point(.hip) else { return nil }
            let dx = shoulder.x - hip.x
            let dy = (shoulder.y - hip.y) * frame.aspectRatio
            guard hypot(dx, dy) >= 0.08 else { return nil }
            return atan2(abs(dx), abs(dy)) * 180 / .pi
        case .pushUp:
            guard let shoulder = point(.shoulder), let hip = point(.hip),
                  let ankle = point(.ankle), abs(ankle.x - shoulder.x) >= 0.1 else { return nil }
            let dx = ankle.x - shoulder.x
            let share = (hip.x - shoulder.x) / dx
            guard (0.15...0.85).contains(share) else { return nil }
            let dy = (ankle.y - shoulder.y) * frame.aspectRatio
            let length = hypot(dx, dy)
            guard length >= 0.15 else { return nil }
            let lineY = shoulder.y + share * (ankle.y - shoulder.y)
            return (hip.y - lineY) * frame.aspectRatio / length
        case .stiffLegDeadlift:
            guard let hip = point(.hip), let knee = point(.knee), let ankle = point(.ankle),
                  let angle = angle(from: hip, vertex: knee, to: ankle,
                                    aspectRatio: frame.aspectRatio) else { return nil }
            return 180 - angle
        case .pullUp, .muscleUp:
            // swing at the top: how far the hips sit forward or back of the shoulders, in torso lengths
            guard let shoulder = point(.shoulder), let hip = point(.hip) else { return nil }
            let torso = hypot(shoulder.x - hip.x, (shoulder.y - hip.y) * frame.aspectRatio)
            guard torso >= 0.05 else { return nil }
            return abs(hip.x - shoulder.x) / torso
        }
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func percentile(_ values: [Double], _ fraction: Double) -> Double {
        let sorted = values.sorted()
        return sorted[Int(Double(sorted.count - 1) * fraction)]
    }
}

/// what the movement looked like during a set, in the exercise's own unit
nonisolated struct MovementDiagnostics: Equatable, Sendable {
    var requiredDepth: Double
    /// deepest movement of the set, measured from the top it started from
    var deepest = 0.0
    /// movements that left the top and came back without reaching the bottom
    var shallow = 0
    var deepestShallow = 0.0
    /// full movements that were faster or slower than the rep window
    var outsideTempo = 0
    /// movements that went down again before coming back up far enough to end a rep
    var incomplete = 0
    /// the set ended partway through a movement
    var unfinished = false
    /// median 3D deviation from side-on when it was above the side-view limit but the set was
    /// still measured.
    var angledView: Double?
    /// the set's joints were clear in less than the 80% advice needs: only clear reps counted
    var partialVisibility: PartialVisibility?
    /// reps of a partly visible set left out because their own frames were not clear enough
    var unclearReps = 0
    /// the reps were counted from the shoulders going down and up, because the arm rubric could not
    /// read the elbow and wrist (a set filmed from the front, or the arm cut off by the picture).
    var countedFromShoulders = false
    /// the squats were counted from the hips going down and up, because the side rubric could not
    /// read the knee and ankle often enough (filmed from the front, the feet at the picture's edge,
    /// or the athlete out of view for a moment).
    var countedFromHips = false

    /// sentences for the result screen, or nil when every movement counted
    func explanation(for definition: ExerciseDefinition, counted: Int) -> String? {
        var parts: [String] = []
        let need = definition.formattedDepth(requiredDepth)
        if counted == 0 && deepest < definition.phases.leaveTop {
            parts.append("Plumb saw almost no movement: the deepest point was \(definition.formattedDepth(deepest)), and a rep needs \(need).")
        }
        if shallow > 0 {
            parts.append("\(shallow) \(shallow == 1 ? "movement was" : "movements were") too shallow to count: the deepest reached \(definition.formattedDepth(deepestShallow)), and a rep needs \(need).")
        }
        if outsideTempo > 0 {
            parts.append("\(outsideTempo) \(outsideTempo == 1 ? "movement was" : "movements were") faster than \(String(format: "%.1f", definition.phases.minimumDuration)) s or slower than \(String(format: "%.0f", definition.phases.maximumDuration)) s.")
        }
        if incomplete > 0 {
            parts.append("\(incomplete) \(incomplete == 1 ? "movement" : "movements") went down again before coming back up far enough to count.")
        }
        if unfinished {
            parts.append("The last movement did not come back to the starting position.")
        }
        if countedFromShoulders {
            parts.append("Plumb could not see your elbow and wrist well enough, so it counted the reps from your shoulders going down and up. It does not measure elbow bend or posture this way: film from the side with your whole arm in view for that.")
        }
        if countedFromHips {
            parts.append("Plumb could not see your knees and ankles well enough, so it counted the squats from your hips going down and up. It gives no posture advice this way: film from the side with your whole body in view for that.")
        }
        if let angledView, angledView >= ViewCheck.clearlyFrontDegrees {
            parts.append("Plumb saw you from the front, so it counted your reps without posture advice. Turn your side to the camera for advice next time.")
        } else if let angledView {
            parts.append("Plumb saw you about \(Int(angledView.rounded()))° from side-on. Turn a little more side-on next time; counts are most reliable from the side.")
        }
        if let partialVisibility {
            let left = unclearReps == 0 ? ""
                : " \(unclearReps) \(unclearReps == 1 ? "rep was" : "reps were") left out because Plumb could not see \(unclearReps == 1 ? "it" : "them") clearly."
            parts.append("Plumb couldn’t see your \(partialVisibility.weakest.rawValue) in \(100 - partialVisibility.weakestShare)% of the set, so it counted only the reps it saw clearly and gives no posture advice.\(left) Keep your whole body in view for advice next time.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
