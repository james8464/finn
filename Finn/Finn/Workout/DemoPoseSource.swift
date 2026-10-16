#if DEBUG
import AVFoundation
import Foundation

/// Deterministic launch-argument input for simulator UI tests; never used in a normal launch.
@MainActor
final class DemoPoseSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    private let startError: CameraSourceError?
    /// Synthetic 3D profile deviation attached to every fourth frame, to exercise the angle check.
    private let profileDeviation: Double?
    private let missingWrist: Bool
    /// `-finn-ui-demo-form-fault`: every rep shows one form fault, so the live advice appears from
    /// the second rep (the squat's chest drops forward, the push-up's hips sag).
    private let formFault: Bool
    private var continuation: AsyncStream<PoseFrame>.Continuation?
    private var feedTask: Task<Void, Never>?
    private var setNumber = 0
    private var exercise: ExerciseKind = .bodyweightSquat

    init(startError: CameraSourceError? = nil, profileDeviation: Double? = nil,
         missingWrist: Bool = false,
         formFault: Bool = ProcessInfo.processInfo.arguments.contains("-finn-ui-demo-form-fault")) {
        self.startError = startError
        self.profileDeviation = profileDeviation
        self.missingWrist = missingWrist
        self.formFault = formFault
    }

    func start() async throws -> AsyncStream<PoseFrame> {
        if let startError { throw startError }
        let stream = AsyncStream(PoseFrame.self, bufferingPolicy: .bufferingNewest(3)) { continuation in
            self.continuation = continuation
        }
        return stream
    }

    func prepareForSet() async {
        setNumber += 1
        let currentSet = setNumber
        let currentExercise = exercise
        feedTask = Task { @MainActor [weak self] in
            let framesPerRep = currentExercise == .stiffLegDeadlift ? 25 : 20
            for index in 0...(6 * framesPerRep) {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(25))
                self?.continuation?.yield(Self.frame(index: index, setNumber: currentSet,
                                                     exercise: currentExercise,
                                                     profileDeviation: self?.profileDeviation,
                                                     missingWrist: self?.missingWrist ?? false,
                                                     formFault: self?.formFault ?? false))
            }
        }
    }

    func configure(for exercise: ExerciseKind) {
        self.exercise = exercise
    }

    func stop() async {
        feedTask?.cancel()
        feedTask = nil
        continuation?.finish()
        continuation = nil
    }

    private static func frame(index: Int, setNumber: Int, exercise: ExerciseKind,
                              profileDeviation: Double?, missingWrist: Bool, formFault: Bool = false) -> PoseFrame {
        let framesPerRep = exercise == .stiffLegDeadlift ? 25 : 20
        let phase = Double(index % framesPerRep) / Double(framesPerRep)
        let motion = (1 - cos(2 * .pi * phase)) / 2
        let late = index / framesPerRep >= 4
        var joints: [BodyJoint: JointPoint]
        func point(_ x: Double, _ y: Double) -> JointPoint {
            JointPoint(x: x, y: y, confidence: 0.95)
        }
        switch exercise {
        case .bodyweightSquat:
            let amplitude = setNumber == 1 ? (late ? 0.13 : 0.20) : 0.24
            let hipY = 0.42 + amplitude * motion
            joints = [
                .leftHip: point(0.47, hipY), .leftKnee: point(0.49, 0.70),
                .leftAnkle: point(0.51, 0.90), .rightHip: point(0.53, hipY),
                .rightKnee: point(0.55, 0.70), .rightAnkle: point(0.57, 0.90),
            ]
        case .pushUp:
            let bend = setNumber == 1 ? (late ? 55.0 : 90.0) : 95.0
            let angle = (170 - bend * motion) * .pi / 180
            let shoulderX = 0.30 + 0.14 * sin(angle)
            let shoulderY = 0.66 + 0.14 * cos(angle)
            let bodyX = 0.85 - shoulderX
            let bodyY = 0.80 - shoulderY
            let bodyLength = hypot(bodyX, bodyY)
            // Keep the first four reps straight; the last two deliberately raise the hips.
            // Offset perpendicular to the body so the fault stays consistent as the arms bend.
            let hipRise = setNumber == 1 && late ? 0.30 * 0.45 * bodyLength : 0
            let hipX = shoulderX + 0.45 * bodyX + bodyY / bodyLength * hipRise
            let hipY = shoulderY + 0.45 * bodyY - bodyX / bodyLength * hipRise
            joints = [
                .leftWrist: point(0.30, 0.80), .leftElbow: point(0.30, 0.66),
                .leftShoulder: point(shoulderX, shoulderY),
                .leftHip: point(hipX, hipY),
                .leftKnee: point((hipX + 0.85) / 2, (hipY + 0.80) / 2),
                .leftAnkle: point(0.85, 0.80),
            ]
        case .staticLunge:
            let bend = setNumber == 1 ? (late ? 48.0 : 75.0) : 85.0
            let angle = (172 - bend * motion) * .pi / 180
            let hipX = 0.45 + 0.20 * sin(angle)
            let hipY = 0.70 + 0.20 * cos(angle)
            joints = [
                .rightAnkle: point(0.45, 0.90), .rightKnee: point(0.45, 0.70),
                .rightHip: point(hipX, hipY), .rightShoulder: point(hipX, hipY - 0.25),
            ]
        case .stiffLegDeadlift:
            let bend = setNumber == 1 ? (late ? 50.0 : 80.0) : 90.0
            let angle = (175 - bend * motion) * .pi / 180
            let shoulderX = 0.50 + 0.30 * sin(angle)
            let shoulderY = 0.55 + 0.30 * cos(angle)
            joints = [
                .leftAnkle: point(0.50, 0.90), .leftKnee: point(0.50, 0.72),
                .leftHip: point(0.50, 0.55), .leftShoulder: point(shoulderX, shoulderY),
                .leftElbow: point(shoulderX, shoulderY + 0.12),
                .leftWrist: point(shoulderX, shoulderY + 0.24),
            ]
        case .pullUp, .muscleUp:
// side view, hands on a bar at y 0.30, arm length 0.16 of the frame height.
            let full = exercise == .pullUp ? 0.9 : 1.9
            let rise = (setNumber == 1 && late ? full * 0.75 : full) * motion * 0.16
            let shoulderY = 0.46 - rise
            let distance = abs(shoulderY - 0.30)
            let reach = sqrt(max(0, 0.08 * 0.08 - distance * distance / 4))
            joints = [
                .leftWrist: point(0.50, 0.30), .leftShoulder: point(0.49, shoulderY),
                .leftElbow: point(0.495 + reach, (shoulderY + 0.30) / 2),
                .leftHip: point(0.48, shoulderY + 0.20), .leftKnee: point(0.49, shoulderY + 0.37),
                .leftAnkle: point(0.47, shoulderY + 0.52), .nose: point(0.53, shoulderY - 0.08),
            ]
        }
        if formFault {
            switch exercise {
            case .bodyweightSquat:
// shoulders tipping 60° forward at the bottom, far past the near-upright shins.
                let lean = 60 * motion * .pi / 180
                for (hip, shoulder) in [(BodyJoint.leftHip, BodyJoint.leftShoulder), (.rightHip, .rightShoulder)] {
                    if let point = joints[hip] {
                        joints[shoulder] = JointPoint(x: point.x + 0.25 * sin(lean), y: point.y - 0.25 * cos(lean),
                                                      confidence: 0.95)
                    }
                }
            case .pushUp:
// hips 0.07 of the picture below the shoulder-to-ankle line, about a third of a torso length.
                if let shoulder = joints[.leftShoulder], let ankle = joints[.leftAnkle] {
                    joints[.leftHip] = point(shoulder.x + 0.45 * (ankle.x - shoulder.x),
                                             shoulder.y + 0.45 * (ankle.y - shoulder.y) + 0.07)
                    joints[.leftKnee] = point(shoulder.x + 0.72 * (ankle.x - shoulder.x),
                                              shoulder.y + 0.72 * (ankle.y - shoulder.y) + 0.035)
                }
            default:
                break
            }
        }
        let visibleJoints = missingWrist && exercise == .pushUp
            ? joints.filter { $0.key != .leftWrist } : joints
        return PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: visibleJoints,
                         profileDeviationDegrees: index.isMultiple(of: 4) ? profileDeviation : nil)
    }
}

/// Debug-only stand-in for a trained exercise classifier, so UI tests can reach the recognition
/// path. It ignores the poses and always answers "squat". It is not a model and measures nothing.
nonisolated final class DemoExerciseClassifier: ExerciseClassifying {
    let windowLength = 30
    let frameRate = 15.0
    func classify(window: [[Float]]) throws -> ClassifierPrediction {
        ClassifierPrediction(label: "squat", confidence: 0.95)
    }
}

@MainActor
final class DemoRecapGenerator: RecapGenerating {
    var available: Bool { false }
    func generate(for comparison: Comparison) async throws -> GeneratedRecap {
        GeneratedRecap(explanation: "", evidenceRepNumbers: [])
    }
}
#endif
