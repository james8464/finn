import AVFoundation
import Foundation

/// Deterministic launch-argument input for simulator UI tests; never used in a normal launch.
@MainActor
final class DemoPoseSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    private var continuation: AsyncStream<PoseFrame>.Continuation?
    private var feedTask: Task<Void, Never>?

    func start() async throws -> AsyncStream<PoseFrame> {
        let stream = AsyncStream(PoseFrame.self, bufferingPolicy: .bufferingNewest(3)) { continuation in
            self.continuation = continuation
        }
        return stream
    }

    func prepareForSet() async {
        feedTask = Task { @MainActor [weak self] in
            for index in 0...120 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(25))
                self?.continuation?.yield(Self.frame(index: index))
            }
        }
    }

    func stop() async {
        feedTask?.cancel()
        feedTask = nil
        continuation?.finish()
        continuation = nil
    }

    private static func frame(index: Int) -> PoseFrame {
        let phase = Double(index % 20) / 20
        let amplitude = index / 20 >= 4 ? 0.13 : 0.20
        let hipY = 0.42 + amplitude * (1 - cos(2 * .pi * phase)) / 2
        let joints: [BodyJoint: JointPoint] = [
            .leftHip: JointPoint(x: 0.47, y: hipY, confidence: 0.99),
            .leftKnee: JointPoint(x: 0.49, y: 0.70, confidence: 0.99),
            .leftAnkle: JointPoint(x: 0.51, y: 0.90, confidence: 0.99),
            .rightHip: JointPoint(x: 0.53, y: hipY, confidence: 0.99),
            .rightKnee: JointPoint(x: 0.55, y: 0.70, confidence: 0.99),
            .rightAnkle: JointPoint(x: 0.57, y: 0.90, confidence: 0.99),
        ]
        return PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: joints)
    }
}

@MainActor
final class DemoRecapGenerator: RecapGenerating {
    var available: Bool { false }
    func generate(for comparison: Comparison) async throws -> GeneratedRecap {
        GeneratedRecap(explanation: "", evidenceRepNumbers: [])
    }
}
