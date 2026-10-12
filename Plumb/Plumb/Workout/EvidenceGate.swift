import Foundation

/// Evidence rules shared by every exercise. They describe tracking quality, not technique,
/// and were first tuned for the squat (`squat-side-v2`).
nonisolated enum EvidenceRubric {
    static let minimumJointConfidence = 0.6
    static let maximumTrackingGap = 0.75
    static let maximumBystanderDuration = 0.35
    static let minimumCoverage = 0.8
    static let maximumAnchorMovement = 0.08
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
        var bystanderStart: TimeInterval?
        for frame in frames {
            if frame.subjectCount > 1 && bystanderStart == nil {
                bystanderStart = frame.time
            }
            if let bystanderStart,
               frame.time - bystanderStart >= EvidenceRubric.maximumBystanderDuration {
                return .reject(.multiplePeople)
            }
            if frame.subjectCount == 1 { bystanderStart = nil }
        }

        let sides: [(BodySide, [BodyJoint])] = [
            (.left, requirement.joints(on: .left)),
            (.right, requirement.joints(on: .right)),
        ]
        let ranked = sides.map { side, joints in
            let complete = frames.filter { frame in joints.allSatisfy { frame.joints[$0] != nil } }
            let confident = complete.filter { frame in
                joints.allSatisfy {
                    (frame.joints[$0]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
                }
            }
            return (side: side, joints: joints, complete: complete.count, confident: confident.count)
        }.sorted { $0.confident > $1.confident }

        guard let best = ranked.first else { return .reject(.missingJoints) }
        let total = Double(frames.count)
        guard Double(best.complete) / total >= EvidenceRubric.minimumCoverage else {
            return .reject(.missingJoints)
        }
        guard Double(best.confident) / total >= EvidenceRubric.minimumCoverage else {
            return .reject(.lowConfidence)
        }

        var lastTrackedTime = first.time
        for frame in frames where frame.subjectCount == 1 && best.joints.allSatisfy({ joint in
            (frame.joints[joint]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
        }) {
            if frame.time - lastTrackedTime > EvidenceRubric.maximumTrackingGap {
                return .reject(.trackingGap)
            }
            lastTrackedTime = frame.time
        }
        if last.time - lastTrackedTime > EvidenceRubric.maximumTrackingGap {
            return .reject(.trackingGap)
        }

        let anchorJoint = requirement.anchor.joint(on: best.side)
        let anchorPoints = frames.compactMap { $0.joints[anchorJoint] }
            .filter { $0.confidence >= EvidenceRubric.minimumJointConfidence }
        guard let minX = anchorPoints.map(\.x).min(), let maxX = anchorPoints.map(\.x).max(),
              let minY = anchorPoints.map(\.y).min(), let maxY = anchorPoints.map(\.y).max(),
              maxX - minX <= EvidenceRubric.maximumAnchorMovement,
              maxY - minY <= EvidenceRubric.maximumAnchorMovement else {
            return .reject(.unstableFraming)
        }
        return .usable(best.side)
    }
}
