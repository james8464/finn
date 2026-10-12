import Foundation

nonisolated enum SquatRubric {
    static let version = "squat-side-v2"
    static let minimumJointConfidence = EvidenceRubric.minimumJointConfidence
    static let descentThreshold = 0.10
    static let completionThreshold = 0.03
    static let ascentFromPeakThreshold = 0.04
    static let minimumHipTravel = 0.15
    static let minimumRepDuration = 0.8
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

    static func analyze(_ frames: [PoseFrame], as definition: ExerciseDefinition) -> AnalysisOutcome {
        let side: BodySide
        switch EvidenceGate.assess(frames, requirement: definition.evidence) {
        case .usable(let acceptedSide): side = acceptedSide
        case .reject(.multiplePeople):
            return .insufficientView("Another person was in view. Keep only yourself in frame and try again.")
        case .reject(.trackingGap):
            return .insufficientView("Tracking was lost during the set. Keep your whole body visible and try again.")
        case .reject:
            return .insufficientView("Move the phone so your full body stays visible.")
        }

        let samples = frames.compactMap { sample(from: $0, signal: definition.signal, side: side) }
        guard samples.count >= 5 else {
            return .insufficientView(definition.copy.keepJointsVisible)
        }

        let opening = Array(samples.prefix(5))
        let baseline = median(opening.map(\.value))
        let travel: (Double) -> Double
        switch definition.signal {
        case .verticalTravel:
            let standingLength = median(opening.map(\.scale)) - baseline
            guard standingLength > definition.minimumBodyScale else {
                return .insufficientView(definition.copy.bodyTooSmall)
            }
            travel = { max(0, ($0 - baseline) / standingLength) }
        case .jointBend:
            guard median(opening.map(\.scale)) > definition.minimumBodyScale else {
                return .insufficientView(definition.copy.bodyTooSmall)
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
        var lastTopTime = samples[0].time
        var reps: [RepMetric] = []
        for (index, sample) in samples.enumerated() {
            let distance = travel(smoothed[index])
            switch phase {
            case .top:
                if distance <= phases.backAtTop {
                    lastTopTime = sample.time
                }
                if distance >= phases.leaveTop {
                    phase = .descending(start: lastTopTime, peak: distance)
                }
            case .descending(let start, let peak):
                let updatedPeak = max(peak, distance)
                if updatedPeak >= phases.reachBottom &&
                    updatedPeak - distance >= phases.returnFromBottom {
                    phase = .ascending(start: start, peak: updatedPeak)
                } else {
                    phase = .descending(start: start, peak: updatedPeak)
                }
            case .ascending(let start, let peak):
                if distance <= phases.backAtTop {
                    let duration = sample.time - start
                    if (phases.minimumDuration...phases.maximumDuration).contains(duration) {
                        reps.append(RepMetric(
                            number: reps.count + 1,
                            startTime: start,
                            endTime: sample.time,
                            relativeRange: peak
                        ))
                    }
                    phase = .top
                }
            }
        }

        let confidence = samples.map(\.confidence).reduce(0, +) / Double(samples.count)
        return .analyzed(SetAnalysis(reps: reps, confidence: confidence,
                                     rubricVersion: definition.rubricVersion))
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
}
