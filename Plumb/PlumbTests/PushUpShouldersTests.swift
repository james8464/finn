import Foundation
import Testing
@testable import Plumb

/// A push-up whose arms the side-view rubric cannot read, such as one filmed from the front with the
/// phone on the floor: the shoulders go down and up while the hands stay planted. These traces are
/// synthetic; their shapes come from three real push-up sets (14 October 2026).
nonisolated struct PushUpShouldersTests {
    /// Shoulders, nose and planted wrists. `hiddenAtBottom` drops every joint for that long around
    /// each bottom, as Vision does when the head leaves the picture. `wristSwing` moves the wrists.
    private func frames(reps: Int, drop: Double = 0.22, period: Double = 1.4,
                        deviation: Double? = 85, noseOnly: ClosedRange<Double>? = nil,
                        hiddenAtBottom: Double = 0, wristSwing: Double = 0) -> [PoseFrame] {
        let duration = Double(reps) * period + 2
        return stride(from: 0.0, through: duration, by: 1.0 / 15).map { time in
            let phase = max(0, time - 1) / period
            let down = time < 1 || phase >= Double(reps) ? 0 : 0.5 - 0.5 * cos(2 * .pi * phase)
            let shoulderY = 0.30 + drop * down
            var joints: [BodyJoint: JointPoint] = [
                .nose: JointPoint(x: 0.5, y: shoulderY - 0.08, confidence: 0.8),
                .leftWrist: JointPoint(x: 0.3, y: 0.85 + wristSwing * down, confidence: 0.8),
                .rightWrist: JointPoint(x: 0.7, y: 0.85 + wristSwing * down, confidence: 0.8),
            ]
            if noseOnly?.contains(time) != true {
                joints[.leftShoulder] = JointPoint(x: 0.4, y: shoulderY, confidence: 0.8)
                joints[.rightShoulder] = JointPoint(x: 0.6, y: shoulderY, confidence: 0.8)
            }
            // Within `hiddenAtBottom` seconds of the deepest point of a rep, the upper body is lost.
            if hiddenAtBottom > 0, time >= 1, phase < Double(reps) {
                let distanceToBottom = abs(phase - phase.rounded(.down) - 0.5) * period
                if distanceToBottom < hiddenAtBottom / 2 {
                    joints[.nose] = nil
                    joints[.leftShoulder] = nil
                    joints[.rightShoulder] = nil
                }
            }
            return PoseFrame(time: time, subjectCount: 1, joints: joints, aspectRatio: 1.78,
                             profileDeviationDegrees: deviation, athleteTracking: .tracked)
        }
    }

    private func repCount(_ frames: [PoseFrame], as definition: ExerciseDefinition = .pushUp) -> Int? {
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: definition) else { return nil }
        return analysis.reps.count
    }

    @Test func countsRepsFromTheShouldersWhenTheArmsCannotBeRead() {
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames(reps: 8), as: .pushUp) else {
            Issue.record("Expected a count from the shoulders")
            return
        }
        #expect(analysis.reps.count == 8)
        #expect(analysis.rubricVersion == "push-up-shoulders-v1")
        #expect(analysis.reps.allSatisfy { $0.postureValue == nil })
    }

    @Test func aPhoneFarAwayCountsTheSameSet() {
        #expect(repCount(frames(reps: 8, drop: 0.08)) == 8)
    }

    @Test func noseStandsInWhereBothShouldersAreLostBriefly() {
        #expect(repCount(frames(reps: 8, noseOnly: 4...4.5)) == 8)
    }

    @Test func aBottomHiddenByTheFrameStillCounts() {
        #expect(repCount(frames(reps: 8, hiddenAtBottom: 0.6)) == 8)
    }

    @Test func standingStillCountsNothing() {
        #expect(repCount(frames(reps: 8, drop: 0.01)) == nil)
    }

    @Test func wristsThatMoveWithTheShouldersAreNotAPushUp() {
        #expect(repCount(frames(reps: 8, wristSwing: 0.2)) == nil)
    }

    @Test func aSetWithoutWristsInThePictureIsNotCounted() {
        let withoutWrists = frames(reps: 8).map { frame -> PoseFrame in
            var joints = frame.joints
            joints[.leftWrist] = nil
            joints[.rightWrist] = nil
            return PoseFrame(time: frame.time, subjectCount: 1, joints: joints, aspectRatio: frame.aspectRatio,
                             profileDeviationDegrees: frame.profileDeviationDegrees, athleteTracking: .tracked)
        }
        #expect(repCount(withoutWrists) == nil)
    }

    @Test func aSquatIsNeverCountedFromTheShoulders() {
        #expect(repCount(frames(reps: 8), as: .squat) == nil)
    }

    @Test func otherExercisesDoNotFallBack() {
        #expect(repCount(frames(reps: 8), as: .staticLunge) == nil)
    }

    @Test func explanationSaysWhyAndThatTheElbowIsNotMeasured() throws {
        let result = ExerciseAnalyzer.analyzeWithDiagnostics(frames(reps: 8), as: .pushUp)
        let text = try #require(result.diagnostics?.explanation(for: .pushUp, counted: 8))
        #expect(text.contains("counted the reps from your shoulders"))
        #expect(text.contains("elbow bend or posture"))
    }
}
