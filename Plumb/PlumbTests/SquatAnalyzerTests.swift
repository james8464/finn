import Foundation
import Testing
@testable import Plumb

struct SquatAnalyzerTests {
    @Test func countsSixCompleteReps() {
        let outcome = SquatAnalyzer.analyze(squatTrace(reps: 6))
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set")
            return
        }

        #expect(analysis.reps.count == 6)
        #expect(analysis.rubricVersion == "squat-side-v5")
        #expect(analysis.reps.map(\.number) == [1, 2, 3, 4, 5, 6])
        #expect(analysis.reps.allSatisfy { $0.duration > 1.3 && $0.duration < 2.1 })
        #expect(analysis.reps.allSatisfy { $0.normalizedHipTravel > 0.35 && $0.normalizedHipTravel < 0.5 })
    }

    @Test func incompleteFinalRepIsNotCounted() {
        var frames = squatTrace(reps: 6)
        frames += squatTrace(reps: 1, startTime: 12.1).filter { $0.time <= 13.2 }

        let outcome = SquatAnalyzer.analyze(frames)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set")
            return
        }

        #expect(analysis.reps.count == 6)
        #expect((analysis.reps.last?.endTime ?? 0) < 12.1)
    }

    @Test func droppedFramesDoNotChangeRepCount() {
        let frames = squatTrace(reps: 6).enumerated().compactMap { index, frame in
            index.isMultiple(of: 4) ? nil : frame
        }

        let outcome = SquatAnalyzer.analyze(frames)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set")
            return
        }

        #expect(analysis.reps.count == 6)
        #expect(analysis.reps.allSatisfy { $0.duration > 1.3 && $0.duration < 2.1 })
    }

    @Test func stationaryTraceHasNoReps() {
        let frames = (0...40).map { index in
            frame(time: Double(index) * 0.1, hipY: 0.42)
        }

        let outcome = SquatAnalyzer.analyze(frames)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected a measured set")
            return
        }

        #expect(analysis.reps.isEmpty)
    }

    @Test func emptyTraceNeedsAnotherView() {
        let outcome = SquatAnalyzer.analyze([])
        guard case .insufficientView = outcome else {
            Issue.record("An empty trace must not become a measured set")
            return
        }
    }

    private func squatTrace(reps: Int, startTime: Double = 0) -> [PoseFrame] {
        (0...(reps * 20)).map { index in
            let time = startTime + Double(index) * 0.1
            let phase = Double(index % 20) / 20
            let hipY = 0.42 + 0.20 * (1 - cos(2 * .pi * phase)) / 2
            return frame(time: time, hipY: hipY)
        }
    }

    private func frame(time: Double, hipY: Double) -> PoseFrame {
        PoseFrame(
            time: time,
            subjectCount: 1,
            joints: [
                .leftHip: JointPoint(x: 0.47, y: hipY, confidence: 0.99),
                .leftKnee: JointPoint(x: 0.49, y: 0.70, confidence: 0.99),
                .leftAnkle: JointPoint(x: 0.51, y: 0.90, confidence: 0.99),
                .rightHip: JointPoint(x: 0.53, y: hipY, confidence: 0.99),
                .rightKnee: JointPoint(x: 0.55, y: 0.70, confidence: 0.99),
                .rightAnkle: JointPoint(x: 0.57, y: 0.90, confidence: 0.99),
            ]
        )
    }
}
