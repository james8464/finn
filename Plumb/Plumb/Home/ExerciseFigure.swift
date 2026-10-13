import SwiftUI

/// A line drawing of one rep of an exercise, seen from the side, for the first screen.
///
/// It is an illustration made from a few joint angles per exercise, not a recording and not a
/// model of correct technique: it shows what Plumb's camera view looks like before the person
/// opens it. The pose for `phase` 0 is the top of the rep and 1 the bottom.
nonisolated struct ExerciseFigure {
    enum Joint: CaseIterable {
        case toe, heel, ankle, knee, hip, shoulder, head, elbow, wrist
        case backToe, backAnkle, backKnee
    }

    /// Body proportions in figure units (about one standing height).
    private static let shin = 0.24, thigh = 0.24, torso = 0.30, neck = 0.11
    private static let upperArm = 0.16, forearm = 0.15, foot = 0.09, heel = 0.03
    static let headRadius = 0.052
    /// Where the hands hold the bar in pull-ups and muscle-ups, with the feet just off the floor.
    static let barHeight = 1.2

    let kind: ExerciseKind

    /// Joint positions, x forward and y up, with the floor at y = 0.
    func pose(at phase: Double) -> [Joint: CGPoint] {
        let t = min(1, max(0, phase))
        func mix(_ top: Double, _ bottom: Double) -> Double { top + (bottom - top) * t }
        var points: [Joint: CGPoint] = [:]
        switch kind {
        case .bodyweightSquat:
            points[.ankle] = CGPoint(x: 0, y: 0.05)
            points[.knee] = Self.point(points[.ankle]!, mix(92, 60), Self.shin)
            points[.hip] = Self.point(points[.knee]!, mix(92, 172), Self.thigh)
            points[.shoulder] = Self.point(points[.hip]!, mix(88, 50), Self.torso)
            points[.head] = Self.point(points[.shoulder]!, mix(86, 60), Self.neck)
            points[.elbow] = Self.point(points[.shoulder]!, mix(-8, 6), Self.upperArm)
            points[.wrist] = Self.point(points[.elbow]!, mix(-6, 8), Self.forearm)
        case .stiffLegDeadlift:
            points[.ankle] = CGPoint(x: 0, y: 0.05)
            points[.knee] = Self.point(points[.ankle]!, mix(91, 86), Self.shin)
            points[.hip] = Self.point(points[.knee]!, mix(92, 104), Self.thigh)
            points[.shoulder] = Self.point(points[.hip]!, mix(88, 14), Self.torso)
            points[.head] = Self.point(points[.shoulder]!, mix(88, 24), Self.neck)
            points[.elbow] = Self.point(points[.shoulder]!, -90, Self.upperArm)
            points[.wrist] = Self.point(points[.elbow]!, -90, Self.forearm)
        case .pushUp:
            // A straight line from ankle to shoulder; the hands stay where they are on the floor.
            let ankle = CGPoint(x: 0, y: 0.05)
            let body = Self.shin + Self.thigh + Self.torso
            let top = Self.point(ankle, 18.5, body)
            let angle = mix(18.5, 9)
            points[.ankle] = ankle
            points[.toe] = CGPoint(x: -0.03, y: 0)
            points[.heel] = CGPoint(x: -0.02, y: 0.09)
            points[.knee] = Self.point(ankle, angle, Self.shin)
            points[.hip] = Self.point(ankle, angle, Self.shin + Self.thigh)
            points[.shoulder] = Self.point(ankle, angle, body)
            points[.head] = Self.point(points[.shoulder]!, angle + 8, Self.neck)
            points[.wrist] = CGPoint(x: top.x - 0.03, y: 0.0)
            points[.elbow] = Self.bend(from: points[.shoulder]!, to: points[.wrist]!,
                                       Self.upperArm, Self.forearm, preferForward: false)
        case .staticLunge:
            let hip = CGPoint(x: mix(-0.02, -0.03), y: mix(0.42, 0.27))
            points[.hip] = hip
            points[.ankle] = CGPoint(x: 0.21, y: 0.05)
            points[.knee] = Self.bend(from: hip, to: points[.ankle]!, Self.thigh, Self.shin, preferForward: true)
            points[.backToe] = CGPoint(x: -0.32, y: 0)
            points[.backAnkle] = CGPoint(x: -0.27, y: 0.07)
            points[.backKnee] = Self.bend(from: hip, to: points[.backAnkle]!, Self.thigh, Self.shin,
                                          preferForward: true)
            points[.shoulder] = Self.point(hip, 90, Self.torso)
            points[.head] = Self.point(points[.shoulder]!, 90, Self.neck)
            points[.elbow] = Self.point(points[.shoulder]!, -96, Self.upperArm)
            points[.wrist] = Self.point(points[.elbow]!, -84, Self.forearm)
        case .pullUp, .muscleUp:
            // Hands stay on the bar; the shoulders rise to it (pull-up) or over it (muscle-up).
            let bar = Self.barHeight
            let wrist = CGPoint(x: 0, y: bar)
            let hang = CGPoint(x: 0, y: bar - Self.upperArm - Self.forearm)
            let shoulder: CGPoint
            let lean: Double
            if kind == .pullUp {
                shoulder = CGPoint(x: mix(0, 0.04), y: mix(hang.y, bar - 0.07))
                lean = mix(-90, -100)
            } else {
                // The chest passes in front of the bar, then the arms press to a straight support.
                shoulder = CGPoint(x: 0.04 * t + 0.13 * sin(.pi * t),
                                   y: mix(hang.y, bar + Self.upperArm + Self.forearm - 0.01))
                lean = mix(-90, -104) - 18 * sin(.pi * t)
            }
            points[.wrist] = wrist
            points[.shoulder] = shoulder
            points[.elbow] = Self.bend(from: shoulder, to: wrist, Self.upperArm, Self.forearm,
                                       preferForward: kind == .pullUp)
            points[.head] = Self.point(shoulder, lean + 180 + (kind == .pullUp ? 0 : 8), Self.neck)
            points[.hip] = Self.point(shoulder, lean, Self.torso)
            points[.knee] = Self.point(points[.hip]!, lean + 6, Self.thigh)
            points[.ankle] = Self.point(points[.knee]!, lean - 28, Self.shin)
            points[.toe] = Self.point(points[.ankle]!, lean + 70, Self.foot * 0.8)
            points[.heel] = points[.ankle]
        }
        if ![.pushUp, .pullUp, .muscleUp].contains(kind), let ankle = points[.ankle] {
            points[.toe] = CGPoint(x: ankle.x + Self.foot, y: 0)
            points[.heel] = CGPoint(x: ankle.x - Self.heel, y: 0)
        }
        return points
    }

    /// The bones to draw, far side first.
    static let bones: [(Joint, Joint)] = [
        (.backToe, .backAnkle), (.backAnkle, .backKnee), (.backKnee, .hip),
        (.heel, .toe), (.heel, .ankle), (.ankle, .knee), (.knee, .hip), (.hip, .shoulder),
        (.shoulder, .elbow), (.elbow, .wrist),
    ]

    /// The line Plumb's camera judges this movement against: a vertical line over the midfoot,
    /// over the hips for the lunge, and the ankle-to-shoulder line for the push-up.
    func guide(at phase: Double) -> (CGPoint, CGPoint) {
        switch kind {
        case .bodyweightSquat, .stiffLegDeadlift:
            return (CGPoint(x: 0.03, y: 0), CGPoint(x: 0.03, y: 0.96))
        case .staticLunge:
            return (CGPoint(x: -0.03, y: 0), CGPoint(x: -0.03, y: 0.96))
        case .pullUp, .muscleUp:
            return (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: Self.barHeight))
        case .pushUp:
            let pose = pose(at: 0)
            let ankle = pose[.ankle]!, shoulder = pose[.shoulder]!
            let dx = shoulder.x - ankle.x, dy = shoulder.y - ankle.y
            return (CGPoint(x: ankle.x - dx * 0.12, y: ankle.y - dy * 0.12),
                    CGPoint(x: shoulder.x + dx * 0.22, y: shoulder.y + dy * 0.22))
        }
    }

    /// The area both ends of the rep cover, so the drawing never jumps while it moves.
    func bounds() -> CGRect {
        var rect = CGRect.null
        for phase in stride(from: 0.0, through: 1.0, by: 0.25) {
            for point in pose(at: phase).values {
                rect = rect.union(CGRect(x: point.x, y: point.y, width: 0, height: 0))
            }
        }
        return rect.insetBy(dx: -Self.headRadius * 1.6, dy: -Self.headRadius * 1.6)
    }

    private static func point(_ from: CGPoint, _ degrees: Double, _ length: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: from.x + cos(radians) * length, y: from.y + sin(radians) * length)
    }

    /// The middle joint of a two-bone limb reaching from `root` to `end`.
    private static func bend(from root: CGPoint, to end: CGPoint, _ first: Double, _ second: Double,
                             preferForward: Bool) -> CGPoint {
        let dx = end.x - root.x, dy = end.y - root.y
        let reach = min(first + second - 0.001, max(abs(first - second) + 0.001, hypot(dx, dy)))
        let cosine = (first * first + reach * reach - second * second) / (2 * first * reach)
        let spread = acos(min(1, max(-1, cosine)))
        let base = atan2(dy, dx)
        let a = CGPoint(x: root.x + cos(base + spread) * first, y: root.y + sin(base + spread) * first)
        let b = CGPoint(x: root.x + cos(base - spread) * first, y: root.y + sin(base - spread) * first)
        return (a.x > b.x) == preferForward ? a : b
    }
}

/// The animated drawing: one slow rep after another, inside the open corners of Plumb's icon.
struct ExerciseFigureView: View {
    let kind: ExerciseKind
    var lineColor: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds for one rep, down and up.
    private let period = 3.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            // Down slowly, hold, then back up; still at the bottom when motion is reduced.
            let phase = reduceMotion ? 0.85 : (1 - cos(2 * .pi * seconds / period)) / 2
            // The plumb bob sways a little, like a real one.
            let sway = reduceMotion ? 0 : sin(2 * .pi * seconds / 2.6) * 1.2
            Canvas { context, size in
                draw(in: &context, size: size, phase: phase, swayDegrees: sway)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Drawing of a \(kind.definition.copy.shareNoun), seen from the side")
        .accessibilityAddTraits(.isImage)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, phase: Double, swayDegrees: Double) {
        let figure = ExerciseFigure(kind: kind)
        let box = figure.bounds()
        let inset: CGFloat = 14
        let room = CGRect(x: inset, y: inset, width: size.width - 2 * inset, height: size.height - 2 * inset)
        let scale = min(room.width / box.width, room.height / box.height)
        let offsetX = room.midX - box.midX * scale
        // The figure sits in the middle of its room.
        let offsetY = room.midY + box.midY * scale
        func place(_ p: CGPoint) -> CGPoint { CGPoint(x: offsetX + p.x * scale, y: offsetY - p.y * scale) }
        let floorY = offsetY

        let width = min(5.5, max(3.5, scale * 0.02))
        let line = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)

        // The floor.
        var floor = Path()
        floor.move(to: CGPoint(x: room.minX, y: floorY))
        floor.addLine(to: CGPoint(x: room.maxX, y: floorY))
        context.stroke(floor, with: .color(lineColor.opacity(0.16)), lineWidth: 1)

        // The plumb line: a string with its bob over the midfoot, or the body line of a push-up.
        if kind == .pushUp {
            let (from, to) = figure.guide(at: phase)
            var guide = Path()
            guide.move(to: place(from))
            guide.addLine(to: place(to))
            context.stroke(guide, with: .color(lineColor.opacity(0.4)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))
        } else {
            let x = place(figure.guide(at: phase).0).x
            let top = CGPoint(x: x, y: room.minY + 4)
            let length = floorY - 16 - top.y
            let angle = swayDegrees * .pi / 180
            let bob = CGPoint(x: top.x + sin(angle) * length, y: top.y + cos(angle) * length)
            var string = Path()
            string.move(to: top)
            string.addLine(to: bob)
            context.stroke(string, with: .color(lineColor.opacity(0.38)), lineWidth: 1)
            var weight = Path()
            weight.move(to: CGPoint(x: bob.x - 5, y: bob.y))
            weight.addLine(to: CGPoint(x: bob.x + 5, y: bob.y))
            weight.addLine(to: CGPoint(x: bob.x, y: bob.y + 10))
            weight.closeSubpath()
            context.fill(weight, with: .color(lineColor.opacity(0.75)))
        }

        // The bar, seen end-on from the side.
        if kind == .pullUp || kind == .muscleUp {
            var bar = Path()
            bar.move(to: place(CGPoint(x: -0.2, y: ExerciseFigure.barHeight)))
            bar.addLine(to: place(CGPoint(x: 0.2, y: ExerciseFigure.barHeight)))
            context.stroke(bar, with: .color(lineColor.opacity(0.55)),
                           style: StrokeStyle(lineWidth: width * 1.4, lineCap: .round))
        }

        let pose = figure.pose(at: phase)
        for (a, b) in ExerciseFigure.bones + [(.shoulder, .head)] {
            guard let p = pose[a], let q = pose[b] else { continue }
            var bone = Path()
            bone.move(to: place(p))
            bone.addLine(to: place(q))
            let far = [ExerciseFigure.Joint.backToe, .backAnkle, .backKnee].contains(a)
            context.stroke(bone, with: .color(lineColor.opacity(far ? 0.5 : 1)), style: line)
        }
        if let head = pose[.head] {
            let radius = ExerciseFigure.headRadius * scale
            let center = place(head)
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                width: 2 * radius, height: 2 * radius)),
                         with: .color(lineColor))
        }
        let dot = width * 0.95
        for joint in [ExerciseFigure.Joint.ankle, .knee, .hip, .shoulder, .elbow, .wrist, .backKnee] {
            guard let p = pose[joint] else { continue }
            let c = place(p)
            context.fill(Path(ellipseIn: CGRect(x: c.x - dot, y: c.y - dot, width: 2 * dot, height: 2 * dot)),
                         with: .color(lineColor))
            context.stroke(Path(ellipseIn: CGRect(x: c.x - dot, y: c.y - dot, width: 2 * dot, height: 2 * dot)),
                           with: .color(HomeStyle.cameraBottom), lineWidth: 1.5)
        }

        // The open corners of the app icon: the camera's view of the set.
        let corner: CGFloat = 26
        let frame = CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)
        var brackets = Path()
        brackets.move(to: CGPoint(x: frame.minX, y: frame.minY + corner))
        brackets.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        brackets.addLine(to: CGPoint(x: frame.minX + corner, y: frame.minY))
        brackets.move(to: CGPoint(x: frame.maxX - corner, y: frame.maxY))
        brackets.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        brackets.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - corner))
        context.stroke(brackets, with: .color(lineColor.opacity(0.6)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
}
