import Foundation

/// Joint-angle summary of a short window of 2D poses. Both the rule-based exercise recognizer
/// and the trained angle classifier read these numbers, so training and the app share one
/// definition. It depends only on `PoseFrame`, which lets the training tool compile it too.
nonisolated struct PoseWindowFeatures: Equatable, Sendable {
    /// Share of frames where the angles below could be measured.
    var coverage: Double
    /// Spread (90th minus 10th percentile) of each angle, in degrees.
    var elbowRange: Double
    var kneeRange: Double
    var hipRange: Double
    /// Spread of the hip-shoulder-elbow angle, which catches arm swings and presses.
    var shoulderRange: Double
    /// Median of each angle, in degrees; 180 is straight.
    var elbowMedian: Double
    var kneeMedian: Double
    var hipMedian: Double
    /// Torso angle from vertical (0 upright, 90 horizontal), median and spread.
    var trunkTiltMedian: Double
    var trunkTiltRange: Double
    /// Hip height spread divided by the median hip-to-ankle length.
    var hipTravel: Double
    /// Horizontal gap between the two ankles divided by the hip-to-ankle length; -1 when the
    /// far ankle is not tracked. Small for a squat, large for a split stance.
    var stance: Double
    /// Wrist height relative to the hip, in hip-to-ankle lengths (positive is below the hip).
    var wristDrop: Double
    /// Wrist height above the shoulder, in hip-to-ankle lengths (75th percentile, so the hang
    /// counts even when the shoulders later pass the hands; positive when hanging from a bar).
    var handLift: Double = 0
    /// Wrist height spread over hip-to-ankle length: near zero when the hands hold a bar.
    var wristTravel: Double = 0
    /// Share of frames with the shoulders above the hands (the top of a muscle-up).
    var shouldersOverHands: Double = 0

    /// Angle models trained before the pull-up rules use the first thirteen; the last three were
    /// added for hanging exercises.
    static let featureNames = [
        "coverage", "elbowRange", "kneeRange", "hipRange", "shoulderRange", "elbowMedian", "kneeMedian",
        "hipMedian", "trunkTiltMedian", "trunkTiltRange", "hipTravel", "stance", "wristDrop",
        "handLift", "wristTravel", "shouldersOverHands",
    ]

    var values: [String: Double] {
        ["coverage": coverage, "elbowRange": elbowRange, "kneeRange": kneeRange,
         "hipRange": hipRange, "shoulderRange": shoulderRange, "elbowMedian": elbowMedian, "kneeMedian": kneeMedian,
         "hipMedian": hipMedian, "trunkTiltMedian": trunkTiltMedian,
         "trunkTiltRange": trunkTiltRange, "hipTravel": hipTravel, "stance": stance,
         "wristDrop": wristDrop, "handLift": handLift, "wristTravel": wristTravel,
         "shouldersOverHands": shouldersOverHands]
    }
}

nonisolated enum PoseWindowFeatureExtractor {
    static let windowDuration: TimeInterval = 2.5
    static let windowStride: TimeInterval = 1.25
    static let minimumConfidence = 0.2
    static let minimumCoverage = 0.5

    /// Overlapping windows of `windowDuration` seconds; a short set gives one window.
    static func windows(_ frames: [PoseFrame]) -> [[PoseFrame]] {
        guard let first = frames.first?.time, let last = frames.last?.time,
              last - first >= windowDuration * 0.8 else { return [] }
        var result: [[PoseFrame]] = []
        var start = first
        repeat {
            let window = frames.filter { $0.time >= start && $0.time < start + windowDuration }
            if window.count >= 8 { result.append(window) }
            start += windowStride
        } while start + windowDuration * 0.8 <= last
        return result
    }

    /// Features for one window, or nil when too few frames show the measured joints.
    static func features(_ window: [PoseFrame]) -> PoseWindowFeatures? {
        guard !window.isEmpty else { return nil }
        let side = trackedSide(in: window)
        var elbows: [Double] = [], knees: [Double] = [], hips: [Double] = [], shoulders: [Double] = []
        var tilts: [Double] = [], hipHeights: [Double] = [], legLengths: [Double] = []
        var stances: [Double] = [], wristDrops: [Double] = []
        var handLifts: [Double] = [], wristHeights: [Double] = [], over = 0, handFrames = 0
        var measured = 0
        for frame in window {
            let aspect = frame.aspectRatio
            func point(_ role: JointRole, _ onSide: BodySide = side) -> (x: Double, y: Double)? {
                guard let joint = frame.joints[role.joint(on: onSide)],
                      joint.confidence >= minimumConfidence else { return nil }
                return (joint.x, joint.y * aspect)
            }
            // Seen from the side, both hips (and both shoulders) nearly overlap, so the far one
            // stands in when Vision loses the near one, as it often does for a body lying down.
            let otherSide: BodySide = side == .left ? .right : .left
            func midline(_ role: JointRole) -> (x: Double, y: Double)? { point(role) ?? point(role, otherSide) }
            guard let shoulder = midline(.shoulder), let hip = midline(.hip),
                  let knee = point(.knee), let ankle = point(.ankle) else { continue }
            measured += 1
            if let elbow = point(.elbow), let wrist = point(.wrist),
               let angle = angle(shoulder, elbow, wrist) {
                elbows.append(angle)
                if let shoulderAngle = self.angle(hip, shoulder, elbow) { shoulders.append(shoulderAngle) }
                let leg = hypot(ankle.x - hip.x, ankle.y - hip.y)
                if leg > 0 { wristDrops.append((wrist.y - hip.y) / leg) }
            }
            if let wrist = point(.wrist) {
                let leg = hypot(ankle.x - hip.x, ankle.y - hip.y)
                if leg > 0 {
                    handLifts.append((shoulder.y - wrist.y) / leg)
                    wristHeights.append(wrist.y)
                }
                handFrames += 1
                // Clearly above, not level with the hands: a high pull-up reaches the bar too.
                if leg > 0 && (wrist.y - shoulder.y) / leg > 0.1 { over += 1 }
            }
            if let angle = angle(hip, knee, ankle) { knees.append(angle) }
            if let angle = angle(shoulder, hip, knee) { hips.append(angle) }
            tilts.append(atan2(abs(shoulder.x - hip.x), hip.y - shoulder.y) * 180 / .pi)
            let leg = hypot(ankle.x - hip.x, ankle.y - hip.y)
            hipHeights.append(hip.y)
            legLengths.append(leg)
            if leg > 0, let farAnkle = point(.ankle, side == .left ? .right : .left) {
                stances.append(abs(farAnkle.x - ankle.x) / leg)
            }
        }
        let coverage = Double(measured) / Double(window.count)
        guard coverage >= minimumCoverage, !knees.isEmpty, !hips.isEmpty else { return nil }
        let leg = median(legLengths)
        return PoseWindowFeatures(
            coverage: coverage,
            elbowRange: spread(elbows), kneeRange: spread(knees), hipRange: spread(hips),
            shoulderRange: spread(shoulders),
            elbowMedian: elbows.isEmpty ? 180 : median(elbows),
            kneeMedian: median(knees), hipMedian: median(hips),
            trunkTiltMedian: median(tilts), trunkTiltRange: spread(tilts),
            hipTravel: leg > 0 ? spread(hipHeights) / leg : 0,
            stance: stances.count * 2 >= measured ? median(stances) : -1,
            wristDrop: wristDrops.isEmpty ? 0 : median(wristDrops),
            handLift: handLifts.isEmpty ? 0 : percentile(handLifts, 0.75),
            wristTravel: leg > 0 ? spread(wristHeights) / leg : 0,
            shouldersOverHands: handFrames > 0 ? Double(over) / Double(handFrames) : 0
        )
    }

    /// The side whose joints Vision tracks with more total confidence in this window.
    static func trackedSide(in window: [PoseFrame]) -> BodySide {
        let roles: [JointRole] = [.shoulder, .elbow, .wrist, .hip, .knee, .ankle]
        func score(_ side: BodySide) -> Double {
            window.reduce(0) { total, frame in
                total + roles.reduce(0) { $0 + (frame.joints[$1.joint(on: side)]?.confidence ?? 0) }
            }
        }
        return score(.left) >= score(.right) ? .left : .right
    }

    private static func angle(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double),
                              _ c: (x: Double, y: Double)) -> Double? {
        let first = (x: a.x - b.x, y: a.y - b.y), second = (x: c.x - b.x, y: c.y - b.y)
        let lengths = hypot(first.x, first.y) * hypot(second.x, second.y)
        guard lengths > 0 else { return nil }
        let cosine = (first.x * second.x + first.y * second.y) / lengths
        return acos(min(1, max(-1, cosine))) * 180 / .pi
    }

    private static func percentile(_ values: [Double], _ fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[Int(Double(sorted.count - 1) * fraction)]
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func spread(_ values: [Double]) -> Double {
        guard values.count >= 3 else { return 0 }
        let sorted = values.sorted()
        let low = sorted[Int(Double(sorted.count - 1) * 0.1)]
        let high = sorted[Int(Double(sorted.count - 1) * 0.9)]
        return high - low
    }
}

/// Hand-written exercise rules on joint-angle features (see `AngleRuleClassifier`).
nonisolated enum AngleRules {
    /// Nil when the window could be a squat or a lunge but the far ankle is not tracked.
    static func label(for f: PoseWindowFeatures) -> String? {
        let moving = max(f.elbowRange, f.kneeRange, f.hipRange, f.shoulderRange)
        if moving < 15 && f.hipTravel < 0.08 { return "none" }
        // Pull-up or muscle-up: hanging with the hands above the shoulders, the body rises while
        // the hands stay put (a press moves the hands and keeps the body still). The shoulders
        // passing above the hands makes it a muscle-up.
        if f.handLift >= 0.25 && f.hipTravel >= 0.15 && f.wristTravel < 0.5 * f.hipTravel
            && f.trunkTiltMedian < 40 {
            return f.shouldersOverHands >= 0.08 ? "muscle_up" : "pull_up"
        }
        // Push-up: body nearly horizontal and straight at the hip, elbows bend, knees stay straight.
        if f.trunkTiltMedian >= 55 && f.hipMedian >= 145 && f.elbowRange >= 20 && f.kneeRange < 30 {
            return "push_up"
        }
        // Stiff-leg deadlift: the torso tips forward through a large hip hinge and comes back up,
        // knees stay nearly straight, and the arms hang straight (a bent-over row bends them).
        if f.hipRange >= 35 && f.trunkTiltRange >= 30 && f.trunkTiltMedian < 60
            && f.kneeRange < 0.5 * f.hipRange && f.kneeMedian >= 140 && f.elbowRange < 35 {
            return "stiff_leg_deadlift"
        }
        // Squat or lunge: knees bend a lot, the hips drop, and the torso stays mostly upright.
        if f.kneeRange >= 35 && f.hipTravel >= 0.12 && f.trunkTiltMedian < 50 {
            if f.stance >= 0.45 { return "static_lunge" }
            if f.stance >= 0 && f.stance < 0.3 { return "squat" }
            return nil
        }
        return "other"
    }
}
