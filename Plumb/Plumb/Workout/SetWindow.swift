import Foundation

/// The part of a capture that is the set itself. On a real phone a person starts the capture at
/// the phone and walks to their spot, then walks back to stop it. Those frames are not the set:
/// the legs leave the picture as the person comes close, and the planted foot travels across the
/// frame. Measured as part of the set, they refused it as a tracking gap or a moving phone.
///
/// The set runs from the first moment the athlete is in position (the exercise's joints clear on
/// one side and its planted joint at its usual place, held for `settleDuration`) to the last such
/// moment, widened over any frames where the athlete is still at their spot with a joint unclear
/// (`presence`): only walking in and out is trimmed, never reps done at the spot. A gap inside the
/// set, or at its ends while the athlete stays at the spot, still counts against it.
nonisolated enum SetWindow {
    /// How long the athlete must stay in position for the set to start, or, read backwards, to end.
    static let settleDuration: TimeInterval = 0.6
    /// Share of the frames in that stretch that must be in position; Vision misses the odd frame.
    static let settleShare = 0.8
    /// How far the planted joint may sit from its usual place, as a share of the frame's width and
    /// of its height. Walking in or out moves it much further; the evidence gate still checks that it
    /// stays still during the set (`EvidenceRubric.maximumAnchorMovement`).
    static let anchorRadius = 0.08
    /// How far the body's reference joint (the hip, or the shoulder for push-ups) may move from its
    /// place during the set, as a share of the frame's width, before the athlete has left the spot.
    static let spotRadius = 0.12
    /// How much larger or smaller the torso may look before the athlete has moved toward or away
    /// from the phone. Walking back to the phone makes it grow well past this before the legs leave
    /// the picture.
    static let torsoTolerance = 0.25

    /// The frames of the set, or all of them when no in-position stretch long enough for a set
    /// exists, so the evidence gate explains the whole capture.
    static func active(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> [PoseFrame] {
        guard let range = activeRange(frames, requirement: requirement) else { return frames }
        return Array(frames[range])
    }

    /// Indices of the set within the capture; nil when nothing needs trimming or no set was found.
    static func activeRange(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> ClosedRange<Int>? {
        guard frames.count >= 2, let inPosition = positions(frames, requirement: requirement),
              let present = presence(frames, requirement: requirement, inPosition: inPosition) else { return nil }
        guard var start = frames.indices.first(where: { index in
            inPosition[index] && settled(frames, inPosition, from: index, forward: true)
        }), var end = frames.indices.last(where: { index in
            inPosition[index] && settled(frames, inPosition, from: index, forward: false)
        }), start < end,
              frames[end].time - frames[start].time >= EvidenceRubric.minimumSetDuration else { return nil }
        // Reps at the spot with a joint unclear stay in the set, so the gate judges them.
        while start > 0 && present[start - 1] { start -= 1 }
        while end < frames.count - 1 && present[end + 1] { end += 1 }
        guard start > 0 || end < frames.count - 1 else { return nil }
        return start...end
    }

    /// For each frame, whether the athlete is at their spot: in position, or seen with the body's
    /// reference joint near its place during the set and the torso the same size, even when an
    /// exercise joint is unclear (an ankle behind a bench). Walking in or back to the phone moves
    /// the reference joint across the frame or makes the torso grow, so those frames are not.
    static func presence(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> [Bool]? {
        guard let inPosition = positions(frames, requirement: requirement) else { return nil }
        return presence(frames, requirement: requirement, inPosition: inPosition)
    }

    private static func presence(_ frames: [PoseFrame], requirement: EvidenceRequirement,
                                 inPosition: [Bool]) -> [Bool]? {
        let side = trackedSide(frames, requirement: requirement)
        let reference: JointRole = requirement.joints.contains(.hip) ? .hip : .shoulder
        let atSpot = frames.indices.filter { inPosition[$0] }
        let places = atSpot.compactMap { clear(frames[$0], reference, side)?.x }
        let torsos = atSpot.compactMap { torso(frames[$0], side: side) }
        guard !places.isEmpty, !torsos.isEmpty else { return inPosition }
        let placeX = median(places)
        let placeTorso = median(torsos)
        guard placeTorso > 0 else { return inPosition }
        return frames.indices.map { index in
            if inPosition[index] { return true }
            let frame = frames[index]
            guard frame.athleteVisible, let point = clear(frame, reference, side),
                  abs(point.x - placeX) <= spotRadius,
                  let length = torso(frame, side: side) else { return false }
            return abs(length / placeTorso - 1) <= torsoTolerance
        }
    }

    private static func clear(_ frame: PoseFrame, _ role: JointRole, _ side: BodySide) -> JointPoint? {
        guard let point = frame.joints[role.joint(on: side)],
              point.confidence >= EvidenceRubric.minimumJointConfidence else { return nil }
        return point
    }

    /// Shoulder-to-hip length, with y in the same unit as x.
    private static func torso(_ frame: PoseFrame, side: BodySide) -> Double? {
        guard let shoulder = clear(frame, .shoulder, side), let hip = clear(frame, .hip, side) else { return nil }
        return hypot(shoulder.x - hip.x, (shoulder.y - hip.y) * frame.aspectRatio)
    }

    /// For each frame, whether the athlete is in position: the exercise's joints clear on the side
    /// seen best over these frames, and its planted joint within `anchorRadius` of its usual place
    /// (the median of where it was seen). Nil when the planted joint was seen fewer than three times.
    static func positions(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> [Bool]? {
        let side = trackedSide(frames, requirement: requirement)
        let anchor = requirement.anchor.joint(on: side)
        let anchors = frames.filter { visible($0, requirement: requirement, side: side) }
            .compactMap { $0.joints[anchor] }
        guard anchors.count >= 3 else { return nil }
        let homeX = median(anchors.map(\.x))
        let homeY = median(anchors.map(\.y))
        return frames.map { frame -> Bool in
            guard visible(frame, requirement: requirement, side: side),
                  let point = frame.joints[anchor] else { return false }
            return abs(point.x - homeX) <= anchorRadius && abs(point.y - homeY) <= anchorRadius
        }
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

    static func visible(_ frame: PoseFrame, requirement: EvidenceRequirement, side: BodySide) -> Bool {
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
