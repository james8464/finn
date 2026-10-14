import Foundation
import Testing
@testable import Plumb

/// A squat filmed from the front: the legs are out of the picture and the shoulders go down and up.
/// The shapes come from three real front-view sets (14 October 2026); these traces are synthetic.
nonisolated struct FrontViewSquatTests {
    /// Shoulders and nose only. `deviation` is the 3D angle from side-on (nil: no estimate).
    private func frontFrames(reps: Int, deviation: Double?, drop: Double = 0.22, period: Double = 1.4,
                             noseOnly: ClosedRange<Double>? = nil) -> [PoseFrame] {
        let duration = Double(reps) * period + 2
        return stride(from: 0.0, through: duration, by: 1.0 / 15).map { time in
            let phase = max(0, time - 1) / period
            let down = time < 1 || phase >= Double(reps) ? 0 : 0.5 - 0.5 * cos(2 * .pi * phase)
            let shoulderY = 0.30 + drop * down
            var joints: [BodyJoint: JointPoint] = [
                .nose: JointPoint(x: 0.5, y: shoulderY - 0.08, confidence: 0.8),
            ]
            if noseOnly?.contains(time) != true {
                joints[.leftShoulder] = JointPoint(x: 0.4, y: shoulderY, confidence: 0.8)
                joints[.rightShoulder] = JointPoint(x: 0.6, y: shoulderY, confidence: 0.8)
            }
            return PoseFrame(time: time, subjectCount: 1, joints: joints, aspectRatio: 1.78,
                             profileDeviationDegrees: deviation, athleteTracking: .tracked)
        }
    }

    @Test func countsRepsFromTheShouldersWhenFacingThePhone() {
        guard case .analyzed(let analysis) = SquatAnalyzer.analyze(frontFrames(reps: 8, deviation: 85)) else {
            Issue.record("Expected a front-view count")
            return
        }
        #expect(analysis.reps.count == 8)
        #expect(analysis.rubricVersion == "squat-front-v1")
        #expect(analysis.reps.allSatisfy { $0.postureValue == nil })
    }

    @Test func nosestandsInWhereBothShouldersAreLostBriefly() {
        let frames = frontFrames(reps: 8, deviation: 85, noseOnly: 4...4.5)
        guard case .analyzed(let analysis) = SquatAnalyzer.analyze(frames) else {
            Issue.record("Expected a front-view count")
            return
        }
        #expect(analysis.reps.count == 8)
    }

    @Test func standingStillCountsNothing() {
        let frames = frontFrames(reps: 8, deviation: 85, drop: 0.01)
        guard case .insufficientView = SquatAnalyzer.analyze(frames) else {
            Issue.record("A person who barely moves must not get reps")
            return
        }
    }

    @Test func withoutA3DEstimateTheSideViewRefusalStays() {
        guard case .insufficientView = SquatAnalyzer.analyze(frontFrames(reps: 8, deviation: nil)) else {
            Issue.record("No 3D estimate: the fallback must not run")
            return
        }
    }

    @Test func aSideOnViewIsNeverCountedFromTheShoulders() {
        guard case .insufficientView = SquatAnalyzer.analyze(frontFrames(reps: 8, deviation: 12)) else {
            Issue.record("Side-on frames without legs must stay refused")
            return
        }
    }

    @Test func otherExercisesDoNotFallBack() {
        guard case .insufficientView = ExerciseAnalyzer.analyze(frontFrames(reps: 8, deviation: 85), as: .pushUp) else {
            Issue.record("Only the squat has a front-view count")
            return
        }
    }

    @Test func explanationSaysWhyAndThatNothingElseIsMeasured() throws {
        let result = ExerciseAnalyzer.analyzeWithDiagnostics(frontFrames(reps: 8, deviation: 85), as: .squat)
        let text = try #require(result.diagnostics?.explanation(for: .squat, counted: 8))
        #expect(text.contains("counted the reps from your shoulders"))
        #expect(text.contains("depth or posture"))
    }
}
