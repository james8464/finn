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
    /// How much larger or smaller the torso may look before the athlete has moved towards or away
    /// from the phone. Walking back to the phone makes it grow well past this before the legs leave
    /// the picture.
    static let torsoTolerance = 0.25
    /// How long an athlete on their feet may be away from their spot, or out of view, and still be in
    /// the set when they come back to it: a step out of the picture during the set. Longer than the
    /// evidence gate allows, so the side rubric refuses such a set and its reps are counted from the
    /// hips. Not for push-ups: getting up from the floor and kneeling at the same place again after
    /// the set read as a rep on a real set (Théophile, 14 October).
    static let maximumAbsence = EvidenceRubric.maximumOcclusionGap

    /// The frames of the set, or all of them when no in-position stretch long enough for a set
    /// exists, so the evidence gate explains the whole capture.
    static func active(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> [PoseFrame] {
        guard let range = activeRange(frames, requirement: requirement) else {
            return frames
        }
        return Array(frames[range])
    }

    /// Indices of the set within the capture; nil when nothing needs trimming or no set was found.
    static func activeRange(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> ClosedRange<Int>? {
        guard frames.count >= 2 else {
            return nil
        }
        let side = trackedSide(frames, requirement: requirement)
        guard let inPosition = positions(frames, requirement: requirement, side: side) else {
            return nil
        }
        return activeRange(frames, inPosition: inPosition, standing: requirement.joints.contains(.hip)) {
            spots(frames, requirement: requirement, inPosition: inPosition)
        }
    }


    /// The set's indices (as `activeRange`) and where the athlete is in each frame (as `spots`),
    /// from one pass over the frames. The live count needs both every 0.4 s; worked out apart,
    /// they went over the whole set four times.
    static func layout(_ frames: [PoseFrame], requirement: EvidenceRequirement)
        -> (range: ClosedRange<Int>?, spots: [Spot]?) {
        let side = trackedSide(frames, requirement: requirement)
        guard let inPosition = positions(frames, requirement: requirement, side: side)
        else {
            return (nil, nil)
        }
        let places = spots(frames, requirement: requirement, inPosition: inPosition)
        let range = frames.count >= 2
            ?
            activeRange(frames, inPosition: inPosition, standing: requirement.joints.contains(.hip)) {
                places } : nil
        return (range, places)
    }

    /// `makeSpots` is called only once a set was found.
    /// `standing`: the exercise is done on the feet, with the hip as the athlete's reference joint.
    private static func activeRange(
        _ frames: [PoseFrame],
        inPosition: [Bool],
        standing: Bool,
        makeSpots: () -> [Spot]
    ) -> ClosedRange<Int>? {
        guard
            var start = frames.indices.first(where: { index in
                inPosition[index] && settled(frames, inPosition, from: index, forward: true)
            }), var end = frames.indices.last(where: { index in
                inPosition[index] && settled(frames, inPosition, from: index, forward: false)
            }), start < end,
            frames[end].time - frames[start].time >= EvidenceRubric.minimumSetDuration else {
            return nil
        }
        // reps at the spot with a joint unclear, or with Vision missing the athlete for a moment,
        // stay in the set, so the gate judges them. A dropout of a few frames right after the last
        // rep used to end the set at that rep's top and drop it.
        let places = makeSpots()
        start = extended(from: start, by: -1, spots: places, frames: frames, standing: standing)
        end = extended(from: end, by: 1, spots: places, frames: frames, standing: standing)
        guard start > 0 || end < frames.count - 1 else {
            return nil
        }
        return start ... end
    }

    /// Moves `index` outward while the athlete is at the spot, across stretches where they are unseen
    /// for at most `EvidenceRubric.maximumTrackingGap` when they are at the spot again after them.
    /// On their feet (`standing`), across stretches unseen or away for at most `maximumAbsence`.
    /// Stops where they leave for longer, or for good: walking in before the set and back to the
    /// phone after it. Until 15 October one frame seen away ended a squat set there, and the reps
    /// done after stepping out of the picture and back were never counted.
    private static func extended(
        from index: Int,
        by step: Int,
        spots: [Spot],
        frames: [PoseFrame],
        standing: Bool
    ) -> Int {
        let absence = standing ? maximumAbsence : EvidenceRubric.maximumTrackingGap
        var edge = index
        var cursor = index + step
        while frames.indices.contains(cursor) {
            if spots[cursor].isAtSpot {
                edge = cursor
                cursor += step
                continue
            }
            if !standing, spots[cursor] == .away {
                return edge
            }
            var probe = cursor
            while
                frames.indices.contains(probe), !spots[probe].isAtSpot,
                standing || spots[probe] == .unseen,
                abs(frames[probe].time - frames[edge].time) <= absence {
                probe += step
            }
            guard frames.indices.contains(probe), spots[probe].isAtSpot else {
                return edge
            }
            edge = probe
            cursor = probe + step
        }
        return edge
    }

    /// Where the athlete is in each frame, relative to their spot during the set: in position, or at
    /// the spot with an exercise joint unclear (an ankle behind a bench), or seen away from it
    /// (walking in or back to the phone moves the hip across the frame or makes the torso grow).
    enum Spot: Equatable {
        /// In position (see `positions`).
        case inPosition
        /// At the spot with an exercise joint unclear.
        case atSpot
        /// Seen away from the spot: the reference joint elsewhere, or the torso a different size.
        case away
        /// Not seen well enough to tell (hidden behind someone, out of view, joints unclear).
        case unseen

        var isAtSpot: Bool {
            self == .inPosition || self == .atSpot
        }
    }

    static func spots(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> [Spot]? {
        let side = trackedSide(frames, requirement: requirement)
        guard let inPosition = positions(frames, requirement: requirement, side: side) else {
            return nil
        }
        return spots(frames, requirement: requirement, inPosition: inPosition)
    }

    /// `inPosition` is measured on one side; where the athlete stands is read from both. A person
    /// turning from the front to their side hides the hip that was followed, and frames at the spot
    /// read as unseen: the live count stopped at the last frame in position.
    private static func spots(
        _ frames: [PoseFrame],
        requirement: EvidenceRequirement,
        inPosition: [Bool]
    ) -> [Spot] {
        let reference: JointRole = requirement.joints.contains(.hip) ? .hip : .shoulder
        let atSpot = frames.indices.filter { inPosition[$0] }
        let places = atSpot.compactMap { centreX(frames[$0], reference) }
        let torsos = atSpot.compactMap { torso(frames[$0]) }
        let placeX = places.isEmpty ? nil : median(places)
        let placeTorso = torsos.isEmpty ? nil : median(torsos)
        return frames.indices.map { index -> Spot in
            if inPosition[index] {
                return .inPosition
            }
            let frame = frames[index]
            guard
                frame.athleteVisible, let placeX, let placeTorso, placeTorso > 0,
                let x = centreX(frame, reference) else {
                return .unseen
            }
            if abs(x - placeX) > spotRadius {
                return .away
            }
            guard let length = torso(frame) else {
                return .unseen
            }
            return abs(length / placeTorso - 1) <= torsoTolerance ? .atSpot : .away
        }
    }

    /// Midpoint of the clear joints of this role, on either side.
    private static func centreX(_ frame: PoseFrame, _ role: JointRole) -> Double? {
        let xs = [BodySide.left, .right].compactMap { clear(frame, role, $0)?.x }
        return xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }

    private static func clear(_ frame: PoseFrame, _ role: JointRole, _ side: BodySide) -> JointPoint? {
        guard
            let point = frame.joints[role.joint(on: side)],
            point.confidence >= EvidenceRubric.minimumJointConfidence else {
            return nil
        }
        return point
    }

    /// Shoulder-to-hip length, with y in the same unit as x: the mean of the sides where both are clear.
    private static func torso(_ frame: PoseFrame) -> Double? {
        let lengths = [BodySide.left, .right].compactMap { side -> Double? in
            guard
                let shoulder = clear(frame, .shoulder, side),
                let hip = clear(frame, .hip, side) else {
                return nil
            }
            return hypot(shoulder.x - hip.x, (shoulder.y - hip.y) * frame.aspectRatio)
        }
        return lengths.isEmpty ? nil : lengths.reduce(0, +) / Double(lengths.count)
    }

    /// For each frame, whether the athlete is in position: the exercise's joints clear on the side
    /// seen best over these frames, and its planted joint within `anchorRadius` of its usual place
    /// (the median of where it was seen). Nil when the planted joint was seen fewer than three times.
    static func positions(_ frames: [PoseFrame], requirement: EvidenceRequirement) -> [Bool]? {
        positions(frames, requirement: requirement, side: trackedSide(frames, requirement: requirement))
    }

    /// `side` is `trackedSide` of these frames.
    private static func positions(
        _ frames: [PoseFrame],
        requirement: EvidenceRequirement,
        side: BodySide
    ) -> [Bool]? {
        let anchor = requirement.anchor.joint(on: side)
        let anchors = frames.filter { visible($0, requirement: requirement, side: side) }
            .compactMap { $0.joints[anchor] }
        guard anchors.count >= 3 else {
            return nil
        }
        let homeX = median(anchors.map(\.x))
        let homeY = median(anchors.map(\.y))
        return frames.map { frame -> Bool in
            guard
                visible(frame, requirement: requirement, side: side),
                let point = frame.joints[anchor] else {
                return false
            }
            return abs(point.x - homeX) <= anchorRadius && abs(point.y - homeY) <= anchorRadius
        }
    }

    /// At least `settleShare` of the frames within `settleDuration` after (or before) `index`
    /// are in position.
    private static func settled(
        _ frames: [PoseFrame],
        _ inPosition: [Bool],
        from index: Int,
        forward: Bool
    ) -> Bool {
        let origin = frames[index].time
        var total = 0
        var held = 0
        var last = index
        var cursor = index
        while frames.indices.contains(cursor), abs(frames[cursor].time - origin) <= settleDuration {
            total += 1
            if inPosition[cursor] {
                held += 1
            }
            last = cursor
            cursor += forward ? 1 : -1
        }
        // the stretch must actually last: a capture that stops just after this frame is not settled.
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
