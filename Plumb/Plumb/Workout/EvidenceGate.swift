import Foundation

/// Evidence rules shared by every exercise. They describe tracking quality, not technique.
/// Version 3 of the squat rubric loosened them after real side-view videos showed Vision
/// reporting hips at about 0.5 confidence: the 0.6 floor of version 2 refused every real set.
nonisolated enum EvidenceRubric {
    static let minimumJointConfidence = 0.3
    static let maximumTrackingGap = 0.75
    static let maximumBystanderDuration = 0.35
    static let minimumCoverage = 0.8
    /// Spread between the 10th and 90th percentile of the still joint's position, so one
    /// misplaced detection does not count as the phone moving.
    static let maximumAnchorMovement = 0.10
    static let minimumSetDuration: TimeInterval = 2
}

nonisolated enum EvidenceGate {
    static func previewStatus(_ frames: [PoseFrame],
                              requirement: EvidenceRequirement = .squat) -> FramingStatus {
        guard frames.count >= 5 else { return .checking }
        let sides: [[BodyJoint]] = [requirement.joints(on: .left), requirement.joints(on: .right)]
        let visible = sides.contains { joints in
            frames.filter { frame in
                frame.subjectCount == 1 && joints.allSatisfy { joint in
                    (frame.joints[joint]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
                }
            }.count >= 4
        }
        return visible ? .landmarksVisible : .adjustPosition
    }

    static func assess(_ frames: [PoseFrame],
                       requirement: EvidenceRequirement = .squat) -> EvidenceAssessment {
        guard let first = frames.first, let last = frames.last,
              last.time - first.time >= EvidenceRubric.minimumSetDuration else {
            return .reject(.tooShort)
        }

        let bystanderFrames = frames.filter { $0.subjectCount > 1 }.count
        if Double(bystanderFrames) / Double(frames.count) > 0.2 {
            return .reject(.multiplePeople)
        }
        if longestBystanderRun(frames) >= EvidenceRubric.maximumBystanderDuration {
            return .reject(.multiplePeople)
        }

        let best = bestSide(frames, requirement: requirement)
        let total = Double(frames.count)
        guard Double(best.complete) / total >= EvidenceRubric.minimumCoverage else {
            return .reject(.missingJoints)
        }
        guard Double(best.confident) / total >= EvidenceRubric.minimumCoverage else {
            return .reject(.lowConfidence)
        }
        if longestTrackingGap(frames, joints: best.joints).duration > EvidenceRubric.maximumTrackingGap {
            return .reject(.trackingGap)
        }
        guard anchorMovement(frames, requirement: requirement, side: best.side)
                <= EvidenceRubric.maximumAnchorMovement else {
            return .reject(.unstableFraming)
        }
        return .usable(best.side)
    }

    /// A sentence with numbers saying why `assess` refused the set, so the app never stays silent.
    static func explanation(for reason: EvidenceReason, frames: [PoseFrame],
                            requirement: EvidenceRequirement = .squat) -> String {
        let total = max(1, frames.count)
        let names = requirement.joints.map(\.rawValue)
        let jointList = names.count > 1
            ? names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
            : names.first ?? "body"
        switch reason {
        case .tooShort:
            let duration = (frames.last?.time ?? 0) - (frames.first?.time ?? 0)
            return String(format: "The set lasted %.1f s. Plumb needs at least %.0f s of movement.",
                          duration, EvidenceRubric.minimumSetDuration)
        case .multiplePeople:
            return "Another person was in view. Keep only yourself in frame and try again."
        case .missingJoints, .lowConfidence:
            let best = bestSide(frames, requirement: requirement)
            let share = Int((100 * Double(reason == .missingJoints ? best.complete : best.confident) / Double(total)).rounded())
            let weakest = weakestJoint(frames, requirement: requirement, side: best.side)
            return "Plumb saw your \(jointList) clearly in \(share)% of the set and needs \(Int(EvidenceRubric.minimumCoverage * 100))%. "
                + "Your \(weakest.role.rawValue) was hardest to see (\(weakest.share)% of frames). "
                + "Move the phone so your whole body is in view, with even light."
        case .trackingGap:
            let gap = longestTrackingGap(frames, joints: bestSide(frames, requirement: requirement).joints)
            return String(format: "Tracking was lost during the set. Keep your whole body visible and try again. "
                          + "Plumb lost your %@ for %.1f s, starting %.1f s into the set.",
                          jointList, gap.duration, gap.start - (frames.first?.time ?? 0))
        case .unstableFraming:
            let movement = anchorMovement(frames, requirement: requirement,
                                          side: bestSide(frames, requirement: requirement).side)
            return "Your \(requirement.anchor.rawValue) moved \(Int((movement * 100).rounded()))% of the frame during the set "
                + "(the limit is \(Int(EvidenceRubric.maximumAnchorMovement * 100))%). Keep the phone still and your "
                + "\(requirement.anchor == .wrist ? "hands" : "feet") planted."
        }
    }

    // MARK: Measurements

    private static func bestSide(_ frames: [PoseFrame], requirement: EvidenceRequirement)
        -> (side: BodySide, joints: [BodyJoint], complete: Int, confident: Int) {
        let sides: [(BodySide, [BodyJoint])] = [
            (.left, requirement.joints(on: .left)),
            (.right, requirement.joints(on: .right)),
        ]
        return sides.map { side, joints in
            let complete = frames.filter { frame in joints.allSatisfy { frame.joints[$0] != nil } }
            let confident = complete.filter { frame in
                joints.allSatisfy {
                    (frame.joints[$0]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
                }
            }
            return (side: side, joints: joints, complete: complete.count, confident: confident.count)
        }.sorted { $0.confident > $1.confident }[0]
    }

    private static func longestBystanderRun(_ frames: [PoseFrame]) -> TimeInterval {
        var longest = 0.0
        var start: TimeInterval?
        for frame in frames {
            if frame.subjectCount > 1 {
                let runStart = start ?? frame.time
                start = runStart
                longest = max(longest, frame.time - runStart)
            } else if frame.subjectCount == 1 {
                start = nil
            }
        }
        return longest
    }

    private static func longestTrackingGap(_ frames: [PoseFrame], joints: [BodyJoint])
        -> (start: TimeInterval, duration: TimeInterval) {
        guard let first = frames.first, let last = frames.last else { return (0, 0) }
        var lastTracked = first.time
        var longest = (start: first.time, duration: 0.0)
        for frame in frames where frame.subjectCount == 1 && joints.allSatisfy({ joint in
            (frame.joints[joint]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
        }) {
            if frame.time - lastTracked > longest.duration {
                longest = (lastTracked, frame.time - lastTracked)
            }
            lastTracked = frame.time
        }
        if last.time - lastTracked > longest.duration {
            longest = (lastTracked, last.time - lastTracked)
        }
        return longest
    }

    private static func anchorMovement(_ frames: [PoseFrame], requirement: EvidenceRequirement,
                                       side: BodySide) -> Double {
        let joint = requirement.anchor.joint(on: side)
        let points = frames.compactMap { $0.joints[joint] }
            .filter { $0.confidence >= EvidenceRubric.minimumJointConfidence }
        guard !points.isEmpty else { return .infinity }
        return max(spread(points.map(\.x)), spread(points.map(\.y)))
    }

    private static func weakestJoint(_ frames: [PoseFrame], requirement: EvidenceRequirement,
                                     side: BodySide) -> (role: JointRole, share: Int) {
        let shares = requirement.joints.map { role -> (JointRole, Int) in
            let seen = frames.filter {
                ($0.joints[role.joint(on: side)]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
            }.count
            return (role, Int((100 * Double(seen) / Double(max(1, frames.count))).rounded()))
        }
        let weakest = shares.min { $0.1 < $1.1 } ?? (requirement.anchor, 0)
        return (weakest.0, weakest.1)
    }

    private static func spread(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[Int(Double(sorted.count - 1) * 0.9)] - sorted[Int(Double(sorted.count - 1) * 0.1)]
    }
}
