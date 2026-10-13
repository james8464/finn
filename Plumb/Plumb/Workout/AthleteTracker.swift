import Foundation

/// Follows the person doing the set from frame to frame, so other people in a gym are ignored
/// instead of refusing the set.
///
/// Before a set it picks the most prominent person (large and near the centre). After that, it
/// remembers where each of their joints was last seen and, in every frame, takes the person whose
/// clear joints sit closest to those positions: the median distance must stay under
/// `allowedShift` of the person's size (a little more the longer they have been out of sight,
/// never more than a third). Comparing joint by joint keeps the track when Vision drops the legs
/// for a frame, which a box around the whole body does not. When nobody fits, or two people fit
/// almost equally well, the frame has no athlete.
///
/// While framing, it moves to someone else only if they are clearly more prominent
/// (`switchFactor`) or the current person has been gone for `reacquireAfter`. Once a set starts,
/// `lock()` keeps it on the same person for the whole set: if they are hidden, frames have no
/// athlete until they reappear, and the evidence gate decides whether the gap was too long. After
/// `reacquireAfter` without a match, a lone person of about the athlete's size is taken as the
/// athlete again (they changed pose while Vision missed them); with several people it waits.
nonisolated struct AthleteTracker {
    struct Box: Equatable {
        /// Centre and diagonal in pixel proportions (y scaled by the frame's height / width).
        let x: Double
        let y: Double
        let size: Double
        /// Half the width and half the height, in the same units.
        var halfWidth = 0.0
        var halfHeight = 0.0

        /// The boxes overlap once this one is widened by `margin` of its size on each side.
        func overlaps(_ other: Box, margin: Double) -> Bool {
            abs(x - other.x) <= halfWidth + other.halfWidth + margin * size
                && abs(y - other.y) <= halfHeight + other.halfHeight + margin * size
        }
    }

    private struct Seen {
        let x: Double
        let y: Double
        let time: TimeInterval
    }

    static let minimumJoints = 4
    /// Joints used to place a person; weaker ones are too often misplaced.
    static let jointConfidence = 0.2
    /// Joints compared with the remembered ones; with fewer, the frame is not trusted.
    static let minimumSharedJoints = 3
    /// A remembered joint older than this no longer counts.
    static let jointMemory: TimeInterval = 2.0
    static let reacquireAfter: TimeInterval = 1.0
    static let switchFactor = 1.5
    /// During a set, a lone person this much smaller or larger than the athlete is not picked up as
    /// them after a loss.
    static let reacquireSizeRange = 0.5...2.0
    /// ...and must overlap where the athlete was last seen, widened by this share of their size.
    static let reacquireMargin = 0.25
    /// Two candidates this close in distance could be swapped; the frame then has no athlete.
    static let ambiguityMargin = 0.05

    private var memory: [BodyJoint: Seen] = [:]
    /// The athlete's size (box diagonal), smoothed and updated only by fairly complete detections.
    private var size = 0.0
    /// Where the athlete's box was when last matched.
    private var lastBox: Box?
    private(set) var isLocked = false
    private var lastMatchTime = -Double.infinity

    var isTracking: Bool { !memory.isEmpty }

    /// Keep following the current person for the whole set.
    mutating func lock() { isLocked = true }

    /// Forget the person; the next frame picks the most prominent one again.
    mutating func reset() {
        forget()
        isLocked = false
    }

    /// The index of the athlete in `people`, or nil when they are not visible in this frame.
    mutating func select(_ people: [[BodyJoint: JointPoint]], aspectRatio: Double,
                         time: TimeInterval) -> Int? {
        let boxes = people.map { Self.box(of: $0, aspectRatio: aspectRatio) }
        if isTracking {
            let limit = Self.allowedShift(after: time - lastMatchTime)
            let distances = people.enumerated().compactMap { index, joints -> (Int, Double)? in
                guard boxes[index] != nil,
                      let distance = distance(to: joints, aspectRatio: aspectRatio, time: time),
                      distance <= limit else { return nil }
                return (index, distance)
            }.sorted { $0.1 < $1.1 }
            if let best = distances.first {
                if distances.count > 1 && distances[1].1 - best.1 < Self.ambiguityMargin {
                    return nil
                }
                var chosen = best.0
                if !isLocked, let leader = Self.mostProminent(boxes, aspectRatio: aspectRatio), leader != chosen,
                   let leaderBox = boxes[leader], let chosenBox = boxes[chosen],
                   Self.prominence(leaderBox, aspectRatio: aspectRatio)
                    > Self.switchFactor * Self.prominence(chosenBox, aspectRatio: aspectRatio) {
                    forget()
                    chosen = leader
                }
                remember(people[chosen], box: boxes[chosen], aspectRatio: aspectRatio, time: time)
                return chosen
            }
            if time - lastMatchTime < Self.reacquireAfter { return nil }
            if isLocked {
                // During a set, pick the athlete up again only when they are clearly the one person
                // in view, at about the size they were. Getting down into a push-up can hide them
                // from Vision for a moment and bring them back far from where they were last seen;
                // before, every remaining frame of the set then had no athlete.
                let candidates = boxes.indices.filter { boxes[$0] != nil }
                guard candidates.count == 1, let box = boxes[candidates[0]], size > 0,
                      Self.reacquireSizeRange.contains(box.size / size),
                      let lastBox, box.overlaps(lastBox, margin: Self.reacquireMargin) else { return nil }
                forget()
                remember(people[candidates[0]], box: box, aspectRatio: aspectRatio, time: time)
                return candidates[0]
            }
            forget()
        }
        guard let pick = Self.mostProminent(boxes, aspectRatio: aspectRatio) else { return nil }
        remember(people[pick], box: boxes[pick], aspectRatio: aspectRatio, time: time)
        return pick
    }

    private mutating func forget() {
        memory = [:]
        size = 0
        lastBox = nil
        lastMatchTime = -.infinity
    }

    /// Median distance, in person sizes, between a candidate's clear joints and where the
    /// athlete's same joints were last seen; nil with too few joints in common.
    private func distance(to joints: [BodyJoint: JointPoint], aspectRatio: Double,
                          time: TimeInterval) -> Double? {
        guard size > 0 else { return nil }
        func gaps(maximumAge: TimeInterval) -> [Double] {
            joints.compactMap { joint, point -> Double? in
                guard point.confidence >= Self.jointConfidence, let seen = memory[joint],
                      time - seen.time <= maximumAge else { return nil }
                return hypot(point.x - seen.x, point.y * aspectRatio - seen.y) / size
            }.sorted()
        }
        // Recent joints first; after a long absence, the last positions seen are all there is.
        var shared = gaps(maximumAge: Self.jointMemory)
        if shared.count < Self.minimumSharedJoints { shared = gaps(maximumAge: .infinity) }
        guard shared.count >= Self.minimumSharedJoints else { return nil }
        return shared[shared.count / 2]
    }

    private mutating func remember(_ joints: [BodyJoint: JointPoint], box: Box?, aspectRatio: Double,
                                   time: TimeInterval) {
        for (joint, point) in joints where point.confidence >= Self.jointConfidence {
            memory[joint] = Seen(x: point.x, y: point.y * aspectRatio, time: time)
        }
        // A detection missing the legs gives a small box; it does not shrink the size.
        if let box {
            lastBox = box
            if size == 0 {
                size = box.size
            } else if box.size >= 0.8 * size {
                size = 0.8 * size + 0.2 * box.size
            }
        }
        lastMatchTime = time
    }

    /// How far the athlete may appear to move, in person sizes, after `elapsed` seconds unseen.
    static func allowedShift(after elapsed: TimeInterval) -> Double {
        min(0.35, 0.12 + 0.25 * max(0, elapsed))
    }

    static func mostProminent(_ boxes: [Box?], aspectRatio: Double) -> Int? {
        boxes.enumerated().compactMap { index, box -> (Int, Double)? in
            guard let box else { return nil }
            return (index, prominence(box, aspectRatio: aspectRatio))
        }.max { $0.1 < $1.1 }?.0
    }

    /// Large and central wins: size, reduced by up to half for a person at the frame's edge.
    static func prominence(_ box: Box, aspectRatio: Double) -> Double {
        let offCentre = hypot(box.x - 0.5, box.y - 0.5 * aspectRatio) / hypot(0.5, 0.5 * aspectRatio)
        return box.size * (1 - 0.5 * min(1, offCentre))
    }

    static func box(of joints: [BodyJoint: JointPoint], aspectRatio: Double) -> Box? {
        let points = joints.values.filter { $0.confidence >= jointConfidence }
        guard points.count >= minimumJoints,
              let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
        let width = maxX - minX
        let height = (maxY - minY) * aspectRatio
        return Box(x: (minX + maxX) / 2, y: (minY + maxY) / 2 * aspectRatio, size: hypot(width, height),
                   halfWidth: width / 2, halfHeight: height / 2)
    }
}
