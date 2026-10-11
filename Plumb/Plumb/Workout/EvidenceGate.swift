import Foundation

nonisolated enum EvidenceGate {
    static func assess(_ frames: [PoseFrame]) -> EvidenceAssessment {
        guard let first = frames.first, let last = frames.last,
              last.time - first.time >= 2 else {
            return .reject(.tooShort)
        }

        let crowded = frames.filter { $0.subjectCount != 1 }.count
        if Double(crowded) / Double(frames.count) > 0.2 {
            return .reject(.multiplePeople)
        }

        let sides: [(BodySide, [BodyJoint])] = [
            (.left, [.leftHip, .leftKnee, .leftAnkle]),
            (.right, [.rightHip, .rightKnee, .rightAnkle]),
        ]
        let ranked = sides.map { side, joints in
            let complete = frames.filter { frame in joints.allSatisfy { frame.joints[$0] != nil } }
            let confident = complete.filter { frame in
                joints.allSatisfy { (frame.joints[$0]?.confidence ?? 0) >= SquatRubric.minimumJointConfidence }
            }
            return (side: side, joints: joints, complete: complete.count, confident: confident.count)
        }.sorted { $0.confident > $1.confident }

        guard let best = ranked.first else { return .reject(.missingJoints) }
        let total = Double(frames.count)
        guard Double(best.complete) / total >= 0.8 else { return .reject(.missingJoints) }
        guard Double(best.confident) / total >= 0.8 else { return .reject(.lowConfidence) }

        var lastTrackedTime: TimeInterval?
        for frame in frames where frame.subjectCount == 1 && best.joints.allSatisfy({ joint in
            (frame.joints[joint]?.confidence ?? 0) >= SquatRubric.minimumJointConfidence
        }) {
            if let lastTrackedTime, frame.time - lastTrackedTime > SquatRubric.maximumTrackingGap {
                return .reject(.trackingGap)
            }
            lastTrackedTime = frame.time
        }

        let ankleJoint: BodyJoint = best.side == .left ? .leftAnkle : .rightAnkle
        let anklePoints = frames.compactMap { $0.joints[ankleJoint] }
            .filter { $0.confidence >= SquatRubric.minimumJointConfidence }
        guard let minX = anklePoints.map(\.x).min(), let maxX = anklePoints.map(\.x).max(),
              let minY = anklePoints.map(\.y).min(), let maxY = anklePoints.map(\.y).max(),
              maxX - minX <= 0.08, maxY - minY <= 0.08 else {
            return .reject(.unstableFraming)
        }
        return .usable(best.side)
    }
}
