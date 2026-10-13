import Foundation

/// The part of a capture that is the set itself. On a real phone a person starts the capture at
/// the phone and walks to their spot, then walks back to stop it. Those frames are not the set:
/// the legs leave the picture as the person comes close, and the planted foot travels across the
/// frame. Measured as part of the set, they refused it as a tracking gap or a moving phone.
///
/// The set runs from the first moment the athlete is in position (the exercise's joints clear on
/// one side and its planted joint at its usual place, held for `settleDuration`) to the last such
/// moment. Only the two ends are trimmed: a gap inside the set still counts against it.
nonisolated enum SetWindow {
    /// How long the athlete must stay in position for the set to start, or, read backwards, to end.
    static let settleDuration: TimeInterval = 0.6
    /// Share of the frames in that stretch that must be in position; Vision misses the odd frame.
    static let settleShare = 0.8
    /// How far the planted joint may sit from its usual place, as a share of the frame's width and
    /// of its height. Walking in or out moves it much further; the evidence gate still checks that it
    /// stays still during the set (`EvidenceRubric.maximumAnchorMovement`).
    static let anchorRadius = 0.08

    /// The frames of the set, or all of them when no in-position stretch long enough for a set
    /// exists, so the evidence gate explains the whole capture.
    static func active(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> [PoseFrame] {
        guard let range = activeRange(frames, requirement: requirement) else { return frames }
        return Array(frames[range])
    }

    /// Indices of the set within the capture; nil when nothing needs trimming or no set was found.
    static func activeRange(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> ClosedRange<Int>? {
        guard frames.count >= 2 else { return nil }
        let side = trackedSide(frames, requirement: requirement)
        let anchor = requirement.anchor.joint(on: side)
        let anchors = frames.filter { visible($0, requirement: requirement, side: side) }
            .compactMap { $0.joints[anchor] }
        guard anchors.count >= 3 else { return nil }
        let homeX = median(anchors.map(\.x))
        let homeY = median(anchors.map(\.y))
        let inPosition = frames.map { frame -> Bool in
            guard visible(frame, requirement: requirement, side: side),
                  let point = frame.joints[anchor] else { return false }
            return abs(point.x - homeX) <= anchorRadius && abs(point.y - homeY) <= anchorRadius
        }

        guard let start = frames.indices.first(where: { index in
            inPosition[index] && settled(frames, inPosition, from: index, forward: true)
        }), let end = frames.indices.last(where: { index in
            inPosition[index] && settled(frames, inPosition, from: index, forward: false)
        }), start < end,
              frames[end].time - frames[start].time >= EvidenceRubric.minimumSetDuration else { return nil }
        guard start > 0 || end < frames.count - 1 else { return nil }
        return start...end
    }

    /// At least `settleShare` of the frames within `settleDuration` after (or before) `index`
    /// are in position.
    private static func settled(_ frames: [PoseFrame], _ inPosition: [Bool], from index: Int,
                                forward: Bool) -> Bool {
        let origin = frames[index].time
        var total = 0
        var held = 0
        var last = index
        var cursor = index
        while frames.indices.contains(cursor), abs(frames[cursor].time - origin) <= settleDuration {
            total += 1
            if inPosition[cursor] { held += 1 }
            last = cursor
            cursor += forward ? 1 : -1
        }
        // The stretch must actually last: a capture that stops just after this frame is not settled.
        return abs(frames[last].time - origin) >= settleDuration * 0.75
            && Double(held) >= settleShare * Double(total)
    }

    private static func visible(_ frame: PoseFrame, requirement: EvidenceRequirement, side: BodySide) -> Bool {
        frame.athleteVisible && requirement.joints(on: side).allSatisfy { joint in
            (frame.joints[joint]?.confidence ?? 0) >= EvidenceRubric.minimumJointConfidence
        }
    }

    /// The side whose required joints are clear in more frames; left when they tie.
    private static func trackedSide(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> BodySide {
        let left = frames.filter { visible($0, requirement: requirement, side: .left) }.count
        let right = frames.filter { visible($0, requirement: requirement, side: .right) }.count
        return right > left ? .right : .left
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
