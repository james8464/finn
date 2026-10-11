import Foundation

nonisolated enum SquatRubric {
    static let version = "squat-side-v1"
    static let minimumJointConfidence = 0.6
    static let descentThreshold = 0.10
    static let completionThreshold = 0.03
    static let ascentFromPeakThreshold = 0.04
    static let minimumHipTravel = 0.15
    static let minimumRepDuration = 0.8
    static let maximumRepDuration = 8.0
}

nonisolated enum SquatAnalyzer {
    private enum Phase {
        case standing
        case descending(start: TimeInterval, peak: Double)
        case ascending(start: TimeInterval, peak: Double)
    }

    private struct Sample {
        let time: TimeInterval
        let hipY: Double
        let ankleY: Double
        let confidence: Double
    }

    static func analyze(_ frames: [PoseFrame]) -> AnalysisOutcome {
        guard case .usable(let side) = EvidenceGate.assess(frames) else {
            return .insufficientView("Move the phone so your full body stays visible.")
        }

        let joints: (BodyJoint, BodyJoint) = side == .left
            ? (.leftHip, .leftAnkle) : (.rightHip, .rightAnkle)
        let samples = frames.compactMap { sample(from: $0, side: joints) }
        guard samples.count >= 5 else {
            return .insufficientView("Keep your hip and ankle visible for the whole set.")
        }

        let opening = Array(samples.prefix(5))
        let standingHipY = median(opening.map(\.hipY))
        let ankleY = median(opening.map(\.ankleY))
        let standingLegLength = ankleY - standingHipY
        guard standingLegLength > 0.1 else {
            return .insufficientView("Move the phone back so your full body is visible.")
        }

        let hipPositions = samples.indices.map { index -> Double in
            let lower = max(0, index - 1)
            let upper = min(samples.count - 1, index + 1)
            let window = samples[lower...upper]
            return window.map(\.hipY).reduce(0, +) / Double(window.count)
        }

        var phase: Phase = .standing
        var lastStandingTime = samples[0].time
        var reps: [RepMetric] = []
        for (index, sample) in samples.enumerated() {
            let travel = max(0, (hipPositions[index] - standingHipY) / standingLegLength)
            switch phase {
            case .standing:
                if travel <= SquatRubric.completionThreshold {
                    lastStandingTime = sample.time
                }
                if travel >= SquatRubric.descentThreshold {
                    phase = .descending(start: lastStandingTime, peak: travel)
                }
            case .descending(let start, let peak):
                let updatedPeak = max(peak, travel)
                if updatedPeak >= SquatRubric.minimumHipTravel &&
                    updatedPeak - travel >= SquatRubric.ascentFromPeakThreshold {
                    phase = .ascending(start: start, peak: updatedPeak)
                } else {
                    phase = .descending(start: start, peak: updatedPeak)
                }
            case .ascending(let start, let peak):
                if travel <= SquatRubric.completionThreshold {
                    let duration = sample.time - start
                    if (SquatRubric.minimumRepDuration...SquatRubric.maximumRepDuration).contains(duration) {
                        reps.append(RepMetric(
                            number: reps.count + 1,
                            startTime: start,
                            endTime: sample.time,
                            normalizedHipTravel: peak
                        ))
                    }
                    phase = .standing
                }
            }
        }

        let confidence = samples.map(\.confidence).reduce(0, +) / Double(samples.count)
        return .analyzed(SetAnalysis(reps: reps, confidence: confidence, rubricVersion: SquatRubric.version))
    }

    private static func validPair(in frame: PoseFrame, hip: BodyJoint, ankle: BodyJoint) -> Bool {
        guard let hipPoint = frame.joints[hip], let anklePoint = frame.joints[ankle] else { return false }
        return hipPoint.confidence >= SquatRubric.minimumJointConfidence &&
            anklePoint.confidence >= SquatRubric.minimumJointConfidence
    }

    private static func sample(from frame: PoseFrame, side: (BodyJoint, BodyJoint)) -> Sample? {
        guard validPair(in: frame, hip: side.0, ankle: side.1),
              let hip = frame.joints[side.0],
              let ankle = frame.joints[side.1] else { return nil }
        return Sample(time: frame.time, hipY: hip.y, ankleY: ankle.y,
                      confidence: min(hip.confidence, ankle.confidence))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
