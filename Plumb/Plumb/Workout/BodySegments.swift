import Foundation

/// one side of the body in one frame, as segments and angles worked out from Vision's 2D joints:
/// upper arm, forearm, torso, thigh and shin; the elbow, shoulder, hip and knee angles; how far the
/// torso and shin lean; and how straight the shoulder, hip and ankle line up. Every form check reads
/// the body through this type, so they all measure the same arm, torso and leg the same way.
///
/// Units: x and y are both in image widths (y is scaled by the frame's aspect ratio, so an angle
/// is the angle seen in the picture), with y pointing down. A joint below `minimumConfidence` is
/// left out, and every value that needs it is nil: a check never measures a joint Vision is unsure of.
/// These are 2D readings of a side view. Seen from another angle they shrink or bend, which is why
/// the checks that use them run only on a side view (`FormChecks`).
nonisolated struct BodySegments: Equatable, Sendable {
    struct Point: Equatable, Sendable {
        let x: Double
        let y: Double
    }

    /// from one joint to the next, in the order the body chains them (shoulder to elbow, hip to knee...)
    struct Segment: Equatable, Sendable {
        let from: Point
        let to: Point

        var dx: Double { to.x - from.x }
        var dy: Double { to.y - from.y }
        var length: Double { hypot(dx, dy) }
        /// degrees between the segment and the vertical, 0 (upright) to 90 (level), whichever way it leans
        var tiltFromVertical: Double? {
            length > 0 ? atan2(abs(dx), abs(dy)) * 180 / .pi : nil
        }
    }

    /// confidence a joint needs before a form check reads it: above the 0.3 the rep count accepts,
    /// the same 0.5 as the posture readings in `ExerciseAnalyzer`
    static let supportingConfidence = 0.5

    let side: BodySide
    let shoulder: Point?
    let elbow: Point?
    let wrist: Point?
    let hip: Point?
    let knee: Point?
    let ankle: Point?

    init(frame: PoseFrame, side: BodySide, minimumConfidence: Double = supportingConfidence) {
        func point(_ role: JointRole) -> Point? {
            guard let joint = frame.joints[role.joint(on: side)], joint.confidence >= minimumConfidence else {
                return nil
            }
            return Point(x: joint.x, y: joint.y * frame.aspectRatio)
        }
        self.side = side
        shoulder = point(.shoulder)
        elbow = point(.elbow)
        wrist = point(.wrist)
        hip = point(.hip)
        knee = point(.knee)
        ankle = point(.ankle)
    }

    func point(_ role: JointRole) -> Point? {
        switch role {
        case .shoulder: shoulder
        case .elbow: elbow
        case .wrist: wrist
        case .hip: hip
        case .knee: knee
        case .ankle: ankle
        }
    }

    // MARK: Segments

    var upperArm: Segment? { Self.segment(shoulder, elbow) }
    var forearm: Segment? { Self.segment(elbow, wrist) }
    /// hip to shoulder
    var torso: Segment? { Self.segment(hip, shoulder) }
    var thigh: Segment? { Self.segment(hip, knee) }
    var shin: Segment? { Self.segment(knee, ankle) }

    // MARK: Joint angles, in degrees; 180 is straight

    /// shoulder, elbow, wrist
    var elbowAngle: Double? { Self.angle(shoulder, elbow, wrist) }
    /// hip, shoulder, elbow: the upper arm against the torso
    var shoulderAngle: Double? { Self.angle(hip, shoulder, elbow) }
    /// shoulder, hip, knee: the torso against the thigh
    var hipAngle: Double? { Self.angle(shoulder, hip, knee) }
    /// hip, knee, ankle
    var kneeAngle: Double? { Self.angle(hip, knee, ankle) }
    /// shoulder, hip, ankle: 180 when the three are in one straight line
    var shoulderHipAnkleAngle: Double? { Self.angle(shoulder, hip, ankle) }

    // MARK: Leans and alignment

    /// torso lean from vertical, 0 upright to 90 level
    var torsoTilt: Double? { torso?.tiltFromVertical }
    /// shin lean from vertical
    var shinTilt: Double? { shin?.tiltFromVertical }
    /// thigh lean from vertical
    var thighTilt: Double? { thigh?.tiltFromVertical }

    /// the thigh's angle above level, in degrees: positive with the hip higher than the knee, 0 with
    /// the thigh level (a parallel squat), negative with the hip below the knee
    var thighAboveLevel: Double? {
        guard let hip, let knee, hip != knee else { return nil }
        return atan2(knee.y - hip.y, abs(knee.x - hip.x)) * 180 / .pi
    }

    /// how far the hip sits off the straight line from the shoulder to the ankle (to the knee when the
    /// ankle is not clear), measured square to that line, in torso lengths (shoulder to hip). Positive
    /// below the line (toward the bottom of the picture: the floor, for a push-up filmed upright),
    /// negative above it. Nil when the line is nearly vertical, where "below" means nothing.
    var hipOffsetFromBodyLine: Double? {
        guard let shoulder, let hip, let end = ankle ?? knee, let torso, torso.length > 0 else { return nil }
        let line = Segment(from: shoulder, to: end)
        guard line.length > torso.length, let tilt = line.tiltFromVertical, tilt >= 30 else { return nil }
        // the normal to the line that points down the picture
        var normal = (x: -line.dy / line.length, y: line.dx / line.length)
        if normal.y < 0 { normal = (-normal.x, -normal.y) }
        let distance = (hip.x - shoulder.x) * normal.x + (hip.y - shoulder.y) * normal.y
        return distance / torso.length
    }

    // MARK: Helpers

    private static func segment(_ from: Point?, _ to: Point?) -> Segment? {
        guard let from, let to else { return nil }
        let segment = Segment(from: from, to: to)
        return segment.length > 0 ? segment : nil
    }

    /// angle at `vertex`, between `a` and `c`, in degrees
    static func angle(_ a: Point?, _ vertex: Point?, _ c: Point?) -> Double? {
        guard let a, let vertex, let c else { return nil }
        let first = (x: a.x - vertex.x, y: a.y - vertex.y)
        let second = (x: c.x - vertex.x, y: c.y - vertex.y)
        let lengths = hypot(first.x, first.y) * hypot(second.x, second.y)
        guard lengths > 0 else { return nil }
        let cosine = (first.x * second.x + first.y * second.y) / lengths
        return acos(min(1, max(-1, cosine))) * 180 / .pi
    }
}
