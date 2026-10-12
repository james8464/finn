import Foundation

nonisolated enum SquatRubric {
    /// v3 (12 October 2026): evidence floor 0.3 instead of 0.6, robust still-joint check, and the
    /// top position taken from the whole set instead of its first frames. v2 refused all 50 real
    /// side-view squat videos it was tried on.
    /// v4 (12 October 2026): follows one athlete, so other people in view no longer refuse the
    /// set, and the athlete may be hidden by someone else for up to 3 s (see `EvidenceRubric`).
    static let version = "squat-side-v4"
    static let minimumJointConfidence = EvidenceRubric.minimumJointConfidence
    static let descentThreshold = 0.10
    /// v3: 0.05 (was 0.03), about twice Vision's hip jitter on real side-view video.
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

/// The side-view squat, now one entry in `ExerciseDefinition`. Kept for existing callers.
nonisolated enum SquatAnalyzer {
    static func analyze(_ frames: [PoseFrame]) -> AnalysisOutcome {
        ExerciseAnalyzer.analyze(frames, as: .squat)
    }
}

/// Counts reps for any `ExerciseDefinition` with one state machine over a single movement signal:
/// top phase → leaving the top → bottom reached → back at the top. It abstains instead of guessing
/// when the evidence gate rejects the view or the signal joints are not tracked.
nonisolated enum ExerciseAnalyzer {
    /// A rep also ends once the person has come back up by 65% of that rep's own depth, so
    /// continuous reps without a full stand still count. Checked against real side-view squats:
    /// at 35% the counts matched an independent dip count; at 45% reps were counted twice.
    /// The next rep is then measured from wherever the person tops out, never from the end of this one.
    static let repEndShareOfDepth = 0.35

    /// Whether 3D camera-angle estimates in the frames may reject the set.
    enum ViewCheckPolicy: Equatable {
        case enforce
        case ignore
    }

    private enum Phase {
        case top
        case descending(start: TimeInterval, peak: Double)
        case ascending(start: TimeInterval, peak: Double)
    }

    private struct Sample {
        let time: TimeInterval
        /// Hip height for vertical travel, joint angle in degrees for a bend.
        let value: Double
        /// Reference height for vertical travel, shortest limb segment for a bend.
        let scale: Double
        let confidence: Double
    }

    static func analyze(_ frames: [PoseFrame], as definition: ExerciseDefinition,
                        viewCheck: ViewCheckPolicy = .enforce) -> AnalysisOutcome {
        analyzeWithDiagnostics(frames, as: definition, viewCheck: viewCheck).outcome
    }

    /// The analysis plus what the movement looked like, so the result can say why a movement
    /// did not count instead of staying silent.
    static func analyzeWithDiagnostics(_ frames: [PoseFrame], as definition: ExerciseDefinition,
                                       viewCheck: ViewCheckPolicy = .enforce)
        -> (outcome: AnalysisOutcome, diagnostics: MovementDiagnostics?) {
        let side: BodySide
        switch EvidenceGate.assess(frames, requirement: definition.evidence) {
        case .usable(let acceptedSide): side = acceptedSide
        case .reject(let reason):
            return (.insufficientView(EvidenceGate.explanation(for: reason, frames: frames,
                                                               requirement: definition.evidence)), nil)
        }
        // Without 3D estimates (simulator, older devices, switched off) this check does not run.
        // Only a clearly frontal view held for several seconds refuses the set; an angled one is
        // measured and the result suggests turning a little.
        var angledView: Double?
        if viewCheck == .enforce {
            switch ViewCheck.assess(frames, expected: definition.expectedView) {
            case .mismatch(let deviation, _):
                return (.insufficientView(definition.expectedView.wrongViewMessage
                    + " Plumb measured about \(Int(deviation.rounded()))° away from the view it needs."), nil)
            case .angled(let deviation, _):
                angledView = deviation
            case .matches, .unavailable:
                break
            }
        }

        let samples = frames.compactMap { sample(from: $0, signal: definition.signal, side: side) }
        guard samples.count >= 5 else {
            return (.insufficientView(definition.copy.keepJointsVisible), nil)
        }

        // The top of the movement is where the person spends the set's highest (squat) or most
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
        case .jointBend:
            baseline = percentile(samples.map(\.value), 0.9)
            guard median(samples.map(\.scale)) > definition.minimumBodyScale else {
                return (.insufficientView(definition.copy.bodyTooSmall), nil)
            }
            travel = { max(0, baseline - $0) }
        }

        let smoothed = samples.indices.map { index -> Double in
            let lower = max(0, index - 1)
            let upper = min(samples.count - 1, index + 1)
            let window = samples[lower...upper]
            return window.map(\.value).reduce(0, +) / Double(window.count)
        }

        let phases = definition.phases
        var phase: Phase = .top
        // Every threshold is measured from the local top: the highest (most open) point since the
        // previous rep ended. In a run of continuous reps the person may not come all the way back
        // to the set's top, and on a real phone that top drifts by a few percent during a set.
        var localTop = Double.infinity
        var lastTopTime = samples[0].time
        var reps: [RepMetric] = []
        var diagnostics = MovementDiagnostics(requiredDepth: phases.reachBottom, angledView: angledView)
        for (index, sample) in samples.enumerated() {
            let distance = travel(smoothed[index])
            switch phase {
            case .top:
                if distance <= localTop + phases.backAtTop {
                    lastTopTime = sample.time
                }
                localTop = min(localTop, distance)
                diagnostics.deepest = max(diagnostics.deepest, distance - localTop)
                if distance - localTop >= phases.leaveTop {
                    phase = .descending(start: lastTopTime, peak: distance)
                }
            case .descending(let start, let peak):
                let updatedPeak = max(peak, distance)
                diagnostics.deepest = max(diagnostics.deepest, updatedPeak - localTop)
                if updatedPeak - localTop >= phases.reachBottom &&
                    updatedPeak - distance >= phases.returnFromBottom {
                    phase = .ascending(start: start, peak: updatedPeak)
                } else if distance <= localTop + phases.backAtTop {
                    // Came back up without reaching the bottom: a shallow movement.
                    diagnostics.shallow += 1
                    diagnostics.deepestShallow = max(diagnostics.deepestShallow, updatedPeak - localTop)
                    lastTopTime = sample.time
                    localTop = distance
                    phase = .top
                } else {
                    phase = .descending(start: start, peak: updatedPeak)
                }
            case .ascending(let start, let peak):
                let depth = peak - localTop
                if distance <= localTop + max(phases.backAtTop, depth * repEndShareOfDepth) {
                    let duration = sample.time - start
                    if (phases.minimumDuration...phases.maximumDuration).contains(duration) {
                        reps.append(RepMetric(
                            number: reps.count + 1,
                            startTime: start,
                            endTime: sample.time,
                            relativeRange: depth
                        ))
                    } else {
                        diagnostics.outsideTempo += 1
                    }
                    lastTopTime = sample.time
                    localTop = distance
                    phase = .top
                }
            }
        }
        if case .top = phase {} else { diagnostics.unfinished = true }

        let confidence = samples.map(\.confidence).reduce(0, +) / Double(samples.count)
        return (.analyzed(SetAnalysis(reps: reps, confidence: confidence,
                                      rubricVersion: definition.rubricVersion)), diagnostics)
    }

    /// The frame where a rep went deepest (hips lowest, or the joint most bent), to draw it.
    static func deepestFrame(of rep: RepMetric, in frames: [PoseFrame],
                             as definition: ExerciseDefinition) -> PoseFrame? {
        guard case .usable(let side) = EvidenceGate.assess(frames, requirement: definition.evidence) else {
            return nil
        }
        let candidates = frames.filter { $0.time >= rep.startTime && $0.time <= rep.endTime }
            .compactMap { frame in sample(from: frame, signal: definition.signal, side: side).map { (frame, $0.value) } }
        switch definition.signal {
        case .verticalTravel: return candidates.max { $0.1 < $1.1 }?.0
        case .jointBend: return candidates.min { $0.1 < $1.1 }?.0
        }
    }

    /// Angle at `vertex` in degrees, with y scaled by the image aspect ratio so it matches x.
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

    private static func sample(from frame: PoseFrame, signal: MovementSignal,
                               side: BodySide) -> Sample? {
        switch signal {
        case .verticalTravel(let jointRole, let referenceRole):
            guard let joint = confidentPoint(jointRole, in: frame, side: side),
                  let reference = confidentPoint(referenceRole, in: frame, side: side) else { return nil }
            return Sample(time: frame.time, value: joint.y, scale: reference.y,
                          confidence: min(joint.confidence, reference.confidence))
        case .jointBend(let fromRole, let vertexRole, let toRole):
            guard let from = confidentPoint(fromRole, in: frame, side: side),
                  let vertex = confidentPoint(vertexRole, in: frame, side: side),
                  let to = confidentPoint(toRole, in: frame, side: side),
                  let angle = angle(from: from, vertex: vertex, to: to,
                                    aspectRatio: frame.aspectRatio) else { return nil }
            let firstSegment = hypot(from.x - vertex.x, (from.y - vertex.y) * frame.aspectRatio)
            let secondSegment = hypot(to.x - vertex.x, (to.y - vertex.y) * frame.aspectRatio)
            return Sample(time: frame.time, value: angle, scale: min(firstSegment, secondSegment),
                          confidence: min(from.confidence, vertex.confidence, to.confidence))
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

/// What the movement looked like during a set, in the exercise's own unit.
nonisolated struct MovementDiagnostics: Equatable, Sendable {
    var requiredDepth: Double
    /// Deepest movement of the set, measured from the top it started from.
    var deepest = 0.0
    /// Movements that left the top and came back without reaching the bottom.
    var shallow = 0
    var deepestShallow = 0.0
    /// Full movements that were faster or slower than the rep window.
    var outsideTempo = 0
    /// The set ended partway through a movement.
    var unfinished = false
    /// Median 3D deviation from side-on when it was above the side-view limit but the set was
    /// still measured.
    var angledView: Double?

    /// Sentences for the result screen, or nil when every movement counted.
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
        if unfinished {
            parts.append("The last movement did not come back to the starting position.")
        }
        if let angledView {
            parts.append("Plumb saw you about \(Int(angledView.rounded()))° from side-on. Turn a little more side-on next time; counts are most reliable from the side.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
