#if DEBUG
import Foundation

/// Debug-only generator of side-view 2D pose sequences for tests and for training the angle
/// classifier. A stick figure with randomized proportions moves through simple joint-angle
/// trajectories; the camera adds yaw, framing, jitter, dropped joints, and weaker far-side
/// confidence. It is a stand-in for real recordings, not a model of real movement.
nonisolated enum SyntheticExerciseMotion {
    static let labels = ["squat", "push_up", "static_lunge", "stiff_leg_deadlift", "pull_up", "muscle_up",
                         "other", "none"]

    struct Settings {
        var duration: ClosedRange<Double> = 7...14
        var frameRate: ClosedRange<Double> = 12...15
        var maximumYawDegrees = 20.0
        var jitterPixels: ClosedRange<Double> = 2...7
        var dropRate: ClosedRange<Double> = 0...0.05
        var repDepth: ClosedRange<Double> = 0.65...1.0
    }

    static func sequence<G: RandomNumberGenerator>(label: String, settings: Settings = Settings(),
                                                   using generator: inout G) -> [PoseFrame] {
        var rng = generator
        defer { generator = rng }
        let body = Body(height: .random(in: 1.55...1.95, using: &rng), using: &rng)
        let motion = Motion(label: label, using: &rng)
        let camera = Camera(maximumYaw: settings.maximumYawDegrees, using: &rng)
        let fps = Double.random(in: settings.frameRate, using: &rng)
        let duration = Double.random(in: settings.duration, using: &rng)
        let jitter = Double.random(in: settings.jitterPixels, using: &rng)
        let dropRate = Double.random(in: settings.dropRate, using: &rng)
        let schedule = Schedule(duration: duration, repDepth: settings.repDepth, using: &rng)

        // Fit the whole movement in a portrait 720 × 1280 frame before sampling it.
        var poses: [(TimeInterval, Skeleton)] = []
        var time = 0.0
        while time <= duration {
            let (amount, phaseTime) = schedule.amount(at: time)
            poses.append((time, motion.skeleton(body: body, amount: amount, time: phaseTime)))
            time += 1 / fps * Double.random(in: 0.9...1.1, using: &rng)
        }
        let projected = poses.map { ($0.0, camera.project($0.1)) }
        let xs = projected.flatMap { $0.1.values.map(\.x) }, ys = projected.flatMap { $0.1.values.map(\.y) }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return [] }
        let width = 720.0, height = 1280.0
        let fill = Double.random(in: 0.5...0.9, using: &rng)
        let scale = fill * min(width / max(maxX - minX, 0.01), height / max(maxY - minY, 0.01))
        let offsetX = Double.random(in: 0...(width - scale * (maxX - minX)), using: &rng)
        let offsetY = Double.random(in: 0...(height - scale * (maxY - minY)), using: &rng)

        return projected.map { time, points in
            var joints: [BodyJoint: JointPoint] = [:]
            // Dictionary iteration is randomized between processes. Keep the seeded generator's
            // joint dropout and jitter reproducible across simulator runs.
            for joint in BodyJoint.allCases {
                guard let point = points[joint] else { continue }
                if Double.random(in: 0..<1, using: &rng) < dropRate { continue }
                let near = camera.nearSide == side(of: joint)
                let x = offsetX + scale * (point.x - minX) + gaussian(using: &rng) * jitter
                let y = offsetY + scale * (maxY - point.y) + gaussian(using: &rng) * jitter
                let confidence = near ? Double.random(in: 0.75...0.99, using: &rng)
                    : Double.random(in: 0.35...0.85, using: &rng)
                joints[joint] = JointPoint(x: min(1, max(0, x / width)), y: min(1, max(0, y / height)),
                                           confidence: confidence)
            }
            return PoseFrame(time: time, subjectCount: 1, joints: joints, aspectRatio: height / width)
        }
    }

    // MARK: Body and camera

    /// World coordinates in meters: x forward, y up, z toward the camera-facing side.
    typealias Skeleton = [BodyJoint: (x: Double, y: Double, z: Double)]

    struct Body {
        let shin, thigh, torso, upperArm, forearm, ankleHeight, hipWidth, shoulderWidth: Double
        init<G: RandomNumberGenerator>(height: Double, using rng: inout G) {
            func part(_ share: Double) -> Double { height * share * .random(in: 0.94...1.06, using: &rng) }
            shin = part(0.25); thigh = part(0.25); torso = part(0.30)
            upperArm = part(0.18); forearm = part(0.16); ankleHeight = part(0.04)
            hipWidth = part(0.17); shoulderWidth = part(0.22)
        }
    }

    struct Camera {
        let yaw: Double
        let facing: Double
        let nearSide: BodySide
        init<G: RandomNumberGenerator>(maximumYaw: Double, using rng: inout G) {
            yaw = .random(in: -maximumYaw...maximumYaw, using: &rng) * .pi / 180
            facing = Bool.random(using: &rng) ? 1 : -1
            nearSide = Bool.random(using: &rng) ? .left : .right
        }

        func project(_ skeleton: Skeleton) -> [BodyJoint: (x: Double, y: Double)] {
            skeleton.mapValues { point in
                // The near side has positive z; mirror z so the chosen side faces the camera.
                let z = nearSide == .left ? point.z : -point.z
                return (x: facing * (point.x * cos(yaw) + z * sin(yaw)), y: point.y)
            }
        }
    }

    /// Reps with rests: amount 0 is the top position, 1 the bottom of a full rep.
    struct Schedule {
        let start: Double, tempo: Double, depths: [Double]
        init<G: RandomNumberGenerator>(duration: Double, repDepth: ClosedRange<Double>, using rng: inout G) {
            start = .random(in: 0.3...1.2, using: &rng)
            tempo = .random(in: 1.4...3.2, using: &rng)
            depths = (0..<40).map { _ in .random(in: repDepth, using: &rng) }
        }

        func amount(at time: Double) -> (Double, Double) {
            guard time > start else { return (0, 0) }
            let rep = Int((time - start) / tempo)
            let phase = (time - start).truncatingRemainder(dividingBy: tempo) / tempo
            return (depths[min(rep, depths.count - 1)] * (1 - cos(2 * .pi * phase)) / 2, time - start)
        }
    }

    // MARK: Movements

    enum Motion {
        case squat(arms: Double, lean: Double)
        case pushUp(sag: Double)
        case lunge(stride: Double, nearLegFront: Bool)
        case deadlift(knee: Double, maximumLean: Double)
        case other(kind: Int)
        case none(arms: Double, plank: Bool)
        /// Hanging from a bar: the shoulders rise by `top` arm lengths at full depth (pull-up about
        /// 0.85, muscle-up about 1.8), and the hips swing forward and back by `swing` meters.
        case hang(top: Double, swing: Double)

        init<G: RandomNumberGenerator>(label: String, using rng: inout G) {
            switch label {
            case "squat": self = .squat(arms: .random(in: 5...100, using: &rng), lean: .random(in: 25...50, using: &rng))
            case "push_up": self = .pushUp(sag: .random(in: -0.03...0.04, using: &rng))
            case "static_lunge": self = .lunge(stride: .random(in: 0.7...0.95, using: &rng),
                                               nearLegFront: Bool.random(using: &rng))
            case "stiff_leg_deadlift": self = .deadlift(knee: .random(in: 5...18, using: &rng),
                                                        maximumLean: .random(in: 60...85, using: &rng))
            case "other": self = .other(kind: Int.random(in: 0..<6, using: &rng))
            case "pull_up": self = .hang(top: .random(in: 0.75...0.95, using: &rng),
                                         swing: .random(in: 0...0.08, using: &rng))
            case "muscle_up": self = .hang(top: .random(in: 1.7...1.95, using: &rng),
                                           swing: .random(in: 0.02...0.12, using: &rng))
            default: self = .none(arms: .random(in: 0...60, using: &rng), plank: Int.random(in: 0..<4, using: &rng) == 0)
            }
        }

        func skeleton(body b: Body, amount s: Double, time: Double) -> Skeleton {
            var sk = Skeleton()
            switch self {
            case .squat(let arms, let lean):
                let ankle = (0.0, b.ankleHeight)
                let knee = along(ankle, b.shin, degrees: 30 * s)
                let hip = along(knee, b.thigh, degrees: -100 * s)
                let shoulder = along(hip, b.torso, degrees: lean * s)
                legs(&sk, b, near: (ankle, knee, hip), far: (ankle, knee, hip))
                trunkAndArms(&sk, b, hip: hip, shoulder: shoulder, upperArm: arms, elbowBend: 10)
            case .pushUp(let sag):
                let wristPoint = (b.shin + b.thigh + b.torso * 0.95, b.ankleHeight)
                let elbowAngle = 170 - 85 * s
                let reach = sqrt(b.upperArm * b.upperArm + b.forearm * b.forearm
                                 - 2 * b.upperArm * b.forearm * cos(elbowAngle * .pi / 180))
                let shoulder = (wristPoint.0, wristPoint.1 + reach)
                let elbow = knee(from: wristPoint, to: shoulder, first: b.forearm, second: b.upperArm, bendForward: false)
                let ankle = (0.0, b.ankleHeight * 1.5)
                let line = (shoulder.0 - ankle.0, shoulder.1 - ankle.1)
                let hip = (ankle.0 + 0.55 * line.0, ankle.1 + 0.55 * line.1 - sag * b.torso * 3)
                let kneePoint = (ankle.0 + 0.28 * line.0, ankle.1 + 0.28 * line.1 - sag * b.torso * 1.5)
                legs(&sk, b, near: (ankle, kneePoint, hip), far: (ankle, kneePoint, hip))
                put(&sk, .leftShoulder, .rightShoulder, shoulder, b.shoulderWidth)
                put(&sk, .leftElbow, .rightElbow, elbow, b.shoulderWidth)
                put(&sk, .leftWrist, .rightWrist, wristPoint, b.shoulderWidth)
            case .lunge(let strideShare, let nearLegFront):
                let stride = strideShare * (b.shin + b.thigh)
                let front = (stride / 2, b.ankleHeight), back = (-stride / 2, b.ankleHeight * 1.5)
                let leg = b.shin + b.thigh
                let top = sqrt(max(0.01, leg * leg - stride * stride / 4)) * 0.985
                let hip = (-0.03, top - s * 0.42 * leg)
                let frontKnee = knee(from: front, to: hip, first: b.shin, second: b.thigh, bendForward: true)
                let backKnee = knee(from: back, to: hip, first: b.shin, second: b.thigh, bendForward: true)
                let frontLeg = (front, frontKnee, hip), backLeg = (back, backKnee, hip)
                legs(&sk, b, near: nearLegFront ? frontLeg : backLeg, far: nearLegFront ? backLeg : frontLeg)
                trunkAndArms(&sk, b, hip: hip, shoulder: along(hip, b.torso, degrees: 6), upperArm: 8, elbowBend: 15)
            case .deadlift(let kneeBend, let maximumLean):
                let ankle = (0.0, b.ankleHeight)
                let knee = along(ankle, b.shin, degrees: kneeBend * 0.6 + 6 * s)
                let hip = along(knee, b.thigh, degrees: -(kneeBend * 0.4 + 14 * s))
                let shoulder = along(hip, b.torso, degrees: maximumLean * s)
                legs(&sk, b, near: (ankle, knee, hip), far: (ankle, knee, hip))
                // Arms hang straight down from the shoulders.
                let elbow = (shoulder.0, shoulder.1 - b.upperArm)
                let wrist = (shoulder.0, shoulder.1 - b.upperArm - b.forearm)
                put(&sk, .leftShoulder, .rightShoulder, shoulder, b.shoulderWidth)
                put(&sk, .leftElbow, .rightElbow, elbow, b.shoulderWidth)
                put(&sk, .leftWrist, .rightWrist, wrist, b.shoulderWidth)
            case .other(let kind):
                other(&sk, b, kind: kind, amount: s, time: time)
            case .hang(let top, let swing):
                let arm = b.upperArm + b.forearm
                let bar = b.ankleHeight + b.shin + b.thigh + b.torso + arm + 0.3
                let wrist = (0.0, bar)
                let rise = top * arm * s
                // From the hang the shoulders rise straight up toward the bar, then over it.
                let shoulder = (-0.04 + (rise > arm ? 0.12 * min(1, (rise - arm) / (0.6 * arm)) : 0),
                                bar - arm + rise)
                let elbow = knee(from: wrist, to: shoulder, first: b.forearm, second: b.upperArm,
                                 bendForward: rise <= arm)
                let sway = swing * sin(time * 2.4)
                let hip = (shoulder.0 + sway, shoulder.1 - b.torso)
                let kneePoint = (hip.0 + 0.04 + sway * 0.5, hip.1 - b.thigh)
                let ankle = (kneePoint.0 - 0.05, kneePoint.1 - b.shin)
                legs(&sk, b, near: (ankle, kneePoint, hip), far: (ankle, kneePoint, hip))
                put(&sk, .leftShoulder, .rightShoulder, shoulder, b.shoulderWidth)
                put(&sk, .leftElbow, .rightElbow, elbow, b.shoulderWidth)
                put(&sk, .leftWrist, .rightWrist, wrist, b.shoulderWidth)
                sk[.nose] = (shoulder.0 + 0.1, shoulder.1 + 0.24, 0)
            case .none(let arms, let plank):
                if plank {
                    return Motion.pushUp(sag: 0.01).skeleton(body: b, amount: 0.02 * sin(time), time: time)
                }
                let sway = 0.01 * sin(time * 1.3)
                let ankle = (0.0, b.ankleHeight)
                let knee = along(ankle, b.shin, degrees: 2 + 100 * sway)
                let hip = along(knee, b.thigh, degrees: -1)
                let shoulder = along(hip, b.torso, degrees: 3 + 100 * sway)
                legs(&sk, b, near: (ankle, knee, hip), far: (ankle, knee, hip))
                trunkAndArms(&sk, b, hip: hip, shoulder: shoulder, upperArm: arms, elbowBend: 15)
            }
            return sk
        }

        /// Curls, presses, overhead triceps, bent-over rows, walking, and arm swings.
        private func other(_ sk: inout Skeleton, _ b: Body, kind: Int, amount s: Double, time: Double) {
            var ankle = (0.0, b.ankleHeight)
            var lean = 4.0
            var kneeBend = 2.0
            var upperArm = 5.0, elbowBend = 10.0
            var farAnkle = ankle
            switch kind {
            case 0: elbowBend = 10 + 120 * s                               // curl
            case 1: upperArm = 100 + 70 * s; elbowBend = 90 - 80 * s       // shoulder press
            case 2: upperArm = 170; elbowBend = 120 - 110 * s              // overhead triceps
            case 3: lean = 60; kneeBend = 20; upperArm = 10 - 40 * s; elbowBend = 10 + 90 * s // row
            case 4:                                                         // walking across
                ankle = (0.45 * time, b.ankleHeight)
                let swing = 0.35 * sin(2 * .pi * time / 1.1)
                farAnkle = (ankle.0 - swing, b.ankleHeight)
                ankle = (ankle.0 + swing, b.ankleHeight)
                upperArm = 25 * sin(2 * .pi * time / 1.1)
            default: upperArm = 175 * s                                    // arm swings
            }
            let hipBase = (ankle.0 + farAnkle.0) / 2
            let knee = along(ankle, b.shin, degrees: kneeBend)
            let hip = (hipBase + b.shin * sin(kneeBend * .pi / 180) * 0.5,
                       b.ankleHeight + (b.shin + b.thigh) * (kind == 3 ? 0.93 : 0.99))
            let farKnee = Motion.knee(from: farAnkle, to: hip, first: b.shin, second: b.thigh, bendForward: true)
            let nearKnee = kind == 4 ? Motion.knee(from: ankle, to: hip, first: b.shin, second: b.thigh,
                                                   bendForward: true) : knee
            legs(&sk, b, near: (ankle, nearKnee, hip), far: (farAnkle, farKnee, hip))
            trunkAndArms(&sk, b, hip: hip, shoulder: along(hip, b.torso, degrees: lean),
                         upperArm: upperArm, elbowBend: elbowBend)
        }

        // MARK: Geometry helpers

        /// The point `length` away from `origin`, `degrees` from vertical toward +x.
        private func along(_ origin: (Double, Double), _ length: Double, degrees: Double) -> (Double, Double) {
            (origin.0 + length * sin(degrees * .pi / 180), origin.1 + length * cos(degrees * .pi / 180))
        }

        /// Middle joint of a two-segment chain from `start` to `end`, bending toward +x or -x.
        static func knee(from start: (Double, Double), to end: (Double, Double),
                         first: Double, second: Double, bendForward: Bool) -> (Double, Double) {
            let dx = end.0 - start.0, dy = end.1 - start.1
            let distance = min(max(hypot(dx, dy), 1e-6), first + second - 1e-6)
            let along = (first * first - second * second + distance * distance) / (2 * distance)
            let height = sqrt(max(0, first * first - along * along))
            let ux = dx / distance, uy = dy / distance
            let base = (start.0 + along * ux, start.1 + along * uy)
            let candidates = [(base.0 - height * uy, base.1 + height * ux), (base.0 + height * uy, base.1 - height * ux)]
            return bendForward ? (candidates[0].0 >= candidates[1].0 ? candidates[0] : candidates[1])
                : (candidates[0].0 <= candidates[1].0 ? candidates[0] : candidates[1])
        }

        private func knee(from start: (Double, Double), to end: (Double, Double),
                          first: Double, second: Double, bendForward: Bool) -> (Double, Double) {
            Motion.knee(from: start, to: end, first: first, second: second, bendForward: bendForward)
        }

        private func legs(_ sk: inout Skeleton, _ b: Body,
                          near: ((Double, Double), (Double, Double), (Double, Double)),
                          far: ((Double, Double), (Double, Double), (Double, Double))) {
            let z = b.hipWidth / 2
            sk[.leftAnkle] = (near.0.0, near.0.1, z); sk[.leftKnee] = (near.1.0, near.1.1, z)
            sk[.leftHip] = (near.2.0, near.2.1, z)
            sk[.rightAnkle] = (far.0.0, far.0.1, -z); sk[.rightKnee] = (far.1.0, far.1.1, -z)
            sk[.rightHip] = (far.2.0, far.2.1, -z)
        }

        private func trunkAndArms(_ sk: inout Skeleton, _ b: Body, hip: (Double, Double),
                                  shoulder: (Double, Double), upperArm: Double, elbowBend: Double) {
            // Arm angles are measured from straight down, positive toward +x.
            let elbow = (shoulder.0 + b.upperArm * sin(upperArm * .pi / 180),
                         shoulder.1 - b.upperArm * cos(upperArm * .pi / 180))
            let forearm = upperArm + elbowBend
            let wrist = (elbow.0 + b.forearm * sin(forearm * .pi / 180),
                         elbow.1 - b.forearm * cos(forearm * .pi / 180))
            put(&sk, .leftShoulder, .rightShoulder, shoulder, b.shoulderWidth)
            put(&sk, .leftElbow, .rightElbow, elbow, b.shoulderWidth)
            put(&sk, .leftWrist, .rightWrist, wrist, b.shoulderWidth)
        }

        private func put(_ sk: inout Skeleton, _ left: BodyJoint, _ right: BodyJoint,
                         _ point: (Double, Double), _ width: Double) {
            sk[left] = (point.0, point.1, width / 2)
            sk[right] = (point.0, point.1, -width / 2)
        }
    }

    private static func side(of joint: BodyJoint) -> BodySide {
        joint.rawValue.hasPrefix("left") ? .left : .right
    }

    private static func gaussian<G: RandomNumberGenerator>(using rng: inout G) -> Double {
        let u = Double.random(in: Double.ulpOfOne..<1, using: &rng), v = Double.random(in: 0..<1, using: &rng)
        return sqrt(-2 * log(u)) * cos(2 * .pi * v)
    }
}

/// Seeded generator so synthetic data and tests are reproducible.
nonisolated struct SyntheticRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
