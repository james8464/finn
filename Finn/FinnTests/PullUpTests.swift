import Foundation
import Testing
@testable import Finn

/// Side-view hanging frames: hands on a bar at y 0.30, arm length 0.16 of the frame height.
private func hangingTrace(reps: Int, rise: Double, framesPerRep: Int = 24, startArm: Double = 172,
                          handsEvery: Int = 1, swing: Double = 0, nose: Bool = true) -> [PoseFrame] {
    (0...(reps * framesPerRep + 8)).map { index in
        let phase = index < 4 ? 0 : Double((index - 4) % framesPerRep) / Double(framesPerRep)
        let motion = index >= 4 + reps * framesPerRep ? 0 : (1 - cos(2 * .pi * phase)) / 2
        let shoulderY = 0.46 - rise * motion * 0.16
        let distance = abs(shoulderY - 0.30)
// straight arms at the hang unless `startArm` bends them.
        let bentReach = sin((180 - startArm) * .pi / 360) * 0.08
        let reach = max(bentReach, sqrt(max(0, 0.08 * 0.08 - distance * distance / 4)))
        let sway = swing * sin(Double(index) * 0.5)
        var joints: [BodyJoint: JointPoint] = [
            .leftShoulder: JointPoint(x: 0.49, y: shoulderY, confidence: 0.9),
            .leftElbow: JointPoint(x: 0.495 + reach, y: (shoulderY + 0.30) / 2, confidence: 0.9),
            .leftHip: JointPoint(x: 0.48 + sway, y: shoulderY + 0.20, confidence: 0.9),
            .leftKnee: JointPoint(x: 0.49 + sway, y: shoulderY + 0.37, confidence: 0.9),
            .leftAnkle: JointPoint(x: 0.47 + sway, y: shoulderY + 0.52, confidence: 0.9),
        ]
        if index % handsEvery == 0 { joints[.leftWrist] = JointPoint(x: 0.50, y: 0.30, confidence: 0.9) }
// the nose sits about a third of an arm length above the shoulders.
        if nose { joints[.nose] = JointPoint(x: 0.53, y: shoulderY - 0.05, confidence: 0.9) }
        return PoseFrame(time: Double(index) / 12, subjectCount: 1, joints: joints)
    }
}

struct PullUpTests {
    @Test func pullUpsCountFromShoulderRise() throws {
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(hangingTrace(reps: 5, rise: 0.85), as: .pullUp) else {
            Issue.record("Five pull-ups must be measured")
            return
        }
        #expect(analysis.reps.count == 5)
        #expect(analysis.rubricVersion == "pull-up-v2")
        #expect(analysis.reps.allSatisfy { $0.relativeRange > 0.7 && $0.relativeRange < 1.0 })
    }

    @Test func halfPullUpsAreExplainedNotCounted() throws {
        let (outcome, diagnostics) = ExerciseAnalyzer.analyseWithDiagnostics(hangingTrace(reps: 4, rise: 0.35), as: .pullUp)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("The set must be measured")
            return
        }
        #expect(analysis.reps.isEmpty)
        let text = try #require(diagnostics?.explanation(for: .pullUp, counted: 0))
        #expect(abs((diagnostics?.deepest ?? 0) - 0.35) < 0.02)
        #expect(text.contains("shoulders up"))
        #expect(text.contains("shoulders up 55% of your arm length"))
    }

    @Test func handsSeenNowAndThenAreEnough() {
// with the bar near the top of the picture, Vision often loses the hands.
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(
            hangingTrace(reps: 4, rise: 0.85, handsEvery: 4), as: .pullUp) else {
            Issue.record("Pull-ups with hands seen in a quarter of the frames must be measured")
            return
        }
        #expect(analysis.reps.count == 4)
    }

    @Test func muscleUpsNeedTheShouldersAboveTheHands() {
        guard case .analyzed(let high) = ExerciseAnalyzer.analyse(hangingTrace(reps: 4, rise: 1.0), as: .muscleUp),
              case .analyzed(let muscleUps) = ExerciseAnalyzer.analyse(hangingTrace(reps: 4, rise: 1.8), as: .muscleUp)
        else {
            Issue.record("Both sets must be measured")
            return
        }
        #expect(high.reps.isEmpty, "a high pull-up is not a muscle-up")
        #expect(muscleUps.reps.count == 4)
    }

    @Test func anyViewIsAcceptedForPullUps() {
        let back = withDeviation(hangingTrace(reps: 4, rise: 0.85), 88)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(back, as: .pullUp) else {
            Issue.record("A back view must be measured for pull-ups")
            return
        }
        #expect(analysis.reps.count == 4)
        #expect(!ViewCheck.previewAsksToTurn([88, 88, 88], expected: .any))
    }

    @Test func checksSayChinStraightArmsAndSwing() throws {
        let frames = hangingTrace(reps: 4, rise: 0.85, swing: 0.06)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .pullUp) else {
            Issue.record("The set must be measured")
            return
        }
        let notes = FormChecks.sentences(for: analysis, frames: frames, definition: .pullUp)
        #expect(notes.contains("Chin above your hands in all 4 reps Finn could check."))
        #expect(notes.contains("Arms straight at the start of every rep."))
        #expect(notes.contains { $0.hasPrefix("Your hips swung about ") })

        let low = hangingTrace(reps: 4, rise: 0.6, startArm: 130, nose: true)
        guard case .analyzed(let lowAnalysis) = ExerciseAnalyzer.analyse(low, as: .pullUp) else {
            Issue.record("The set must be measured")
            return
        }
        let lowNotes = FormChecks.sentences(for: lowAnalysis, frames: low, definition: .pullUp)
        #expect(lowNotes.contains { $0.hasPrefix("Chin above your hands in 0 of") })
        #expect(lowNotes.contains { $0.hasPrefix("Arms not fully straight at the start of rep 1") })
    }

    @Test func noChinSentenceWithoutTheNose() {
        let frames = hangingTrace(reps: 3, rise: 0.85, nose: false)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .pullUp) else {
            Issue.record("The set must be measured")
            return
        }
        #expect(!FormChecks.sentences(for: analysis, frames: frames, definition: .pullUp).contains { $0.hasPrefix("Chin") })
    }

    @Test func rulesRecognizePullUpsAndMuscleUps() {
        var rng = SyntheticRandom(seed: 1013)
        for _ in 0..<10 {
            let pull = SyntheticExerciseMotion.sequence(label: "pull_up", using: &rng)
            let muscle = SyntheticExerciseMotion.sequence(label: "muscle_up", using: &rng)
            #expect({ if case .recognized(.pullUp, _) = AngleRecognizer.recognise(pull, using: AngleRuleClassifier()) { return true }; return false }())
            #expect({ if case .recognized(.muscleUp, _) = AngleRecognizer.recognise(muscle, using: AngleRuleClassifier()) { return true }; return false }())
        }
    }

    @Test func overheadPressesAreNotPullUps() {
// the synthetic "other" class includes shoulder presses and overhead triceps extensions.
        var rng = SyntheticRandom(seed: 1014)
        for _ in 0..<30 {
            let frames = SyntheticExerciseMotion.sequence(label: "other", using: &rng)
            let result = AngleRecognizer.recognise(frames, using: AngleRuleClassifier())
            #expect(result != .recognized(.pullUp, agreement: 1) && {
                if case .recognized(let kind, _) = result { return kind != .pullUp && kind != .muscleUp }
                return true
            }())
        }
    }
}
