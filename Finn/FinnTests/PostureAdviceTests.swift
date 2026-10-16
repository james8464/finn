import Foundation
import Testing
@testable import Finn

struct PostureAdviceTests {
    @Test func squatTorsoChangeGetsPostureAdvice() throws {
        let frames = (0 ... 120).map { index -> PoseFrame in
            let depth = 0.2 * (1 - cos(2 * .pi * Double(index % 20) / 20)) / 2
            let original = squatFrame(time: Double(index) * 0.1, hipY: 0.42 + depth)
            var joints = original.joints
            for (hipJoint, shoulderJoint) in [(BodyJoint.leftHip, BodyJoint.leftShoulder),
                                              (.rightHip, .rightShoulder)] {
                let hip = joints[hipJoint]!
                joints[shoulderJoint] = JointPoint(
                    x: hip.x + (index / 20 >= 4 ? 0.09 : 0),
                    y: hip.y - 0.25,
                    confidence: 0.95
                )
            }
            return PoseFrame(time: original.time, subjectCount: 1, joints: joints)
        }
        let analysis = try measured(ExerciseAnalyzer.analyse(frames, as: .squat))
        #expect(analysis.reps.count == 6)
        #expect(CueSelector.select(from: analysis, exercise: .squat)?.kind == .torsoTiltIncreased)
    }

    @Test func pushUpHipDropGetsOneSpecificNextAction() throws {
        let frames = pushUpTrace(reps: 6).enumerated().map { index, frame in
            guard index / 20 >= 4 else {
                return frame
            }
            var joints = frame.joints
            if let hip = joints[.leftHip] {
                joints[.leftHip] = JointPoint(x: hip.x, y: hip.y + 0.09, confidence: hip.confidence)
            }
            return PoseFrame(
                time: frame.time,
                subjectCount: frame.subjectCount,
                joints: joints,
                aspectRatio: frame.aspectRatio
            )
        }
        let analysis = try measured(ExerciseAnalyzer.analyse(frames, as: .pushUp))
        let cue = CueSelector.select(from: analysis, exercise: .pushUp)
        #expect(cue?.repNumbers == [5, 6])
        #expect(cue?
            .observation ==
            "Your hips sat lower relative to your shoulder-to-ankle line in the last two reps.")
        #expect(cue?.nextAction == "Try keeping your hips aligned with your shoulders and ankles.")
    }

    @Test func lungeTorsoChangeGetsPostureAdvice() throws {
        let frames = lungeTrace(reps: 6).enumerated().map { index, frame in
            guard index / 20 >= 4 else {
                return frame
            }
            var joints = frame.joints
            if let shoulder = joints[.rightShoulder] {
                joints[.rightShoulder] = JointPoint(
                    x: shoulder.x + 0.09,
                    y: shoulder.y,
                    confidence: shoulder.confidence
                )
            }
            return PoseFrame(time: frame.time, subjectCount: frame.subjectCount, joints: joints)
        }
        let analysis = try measured(ExerciseAnalyzer.analyse(frames, as: .staticLunge))
        let cue = CueSelector.select(from: analysis, exercise: .staticLunge)
        #expect(cue?.repNumbers == [5, 6])
        #expect(cue?.observation == "Your torso tilted farther from upright in the last two reps.")
    }

    @Test func angledViewDoesNotReceivePostureAdvice() throws {
        let frames = pushUpTrace(reps: 6).enumerated().map { index, frame in
            var joints = frame.joints
            if index / 20 >= 4, let hip = joints[.leftHip] {
                joints[.leftHip] = JointPoint(x: hip.x, y: hip.y + 0.09, confidence: hip.confidence)
            }
            return PoseFrame(
                time: frame.time,
                subjectCount: 1,
                joints: joints,
                aspectRatio: frame.aspectRatio,
                profileDeviationDegrees: 45
            )
        }
        let analysis = try measured(ExerciseAnalyzer.analyse(frames, as: .pushUp))
        #expect(analysis.reps.count == 6)
        #expect(CueSelector.select(from: analysis, exercise: .pushUp) == nil)
    }

    @Test func missingPostureJointPreservesRepCountWithoutGuessing() throws {
        let frames = pushUpTrace(reps: 6).map { frame in
            PoseFrame(
                time: frame.time,
                subjectCount: 1,
                joints: frame.joints.filter { $0.key != .leftHip }
            )
        }
        let analysis = try measured(ExerciseAnalyzer.analyse(frames, as: .pushUp))
        #expect(analysis.reps.count == 6)
        #expect(CueSelector.select(from: analysis, exercise: .pushUp) == nil)
    }

    @Test func deadliftTracksKneeBendAndUsesSpecificWording() throws {
        let analysis = try measured(ExerciseAnalyzer.analyse(hingeTrace(reps: 6), as: .stiffLegDeadlift))
        #expect(analysis.reps.count == 6)
        #expect(analysis.reps.allSatisfy { $0.postureValue != nil })

        let reps = (0 ..< 6).map { (index: Int) -> RepMetric in
            RepMetric(
                number: index + 1,
                startTime: Double(index) * 2,
                endTime: Double(index + 1) * 2,
                relativeRange: 75.0,
                postureValue: index >= 4 ? 27.0 : 9.0
            )
        }
        let changed = SetAnalysis(
            reps: reps,
            confidence: 0.9,
            rubricVersion: ExerciseDefinition.stiffLegDeadlift.rubricVersion
        )
        let cue = CueSelector.select(from: changed, exercise: .stiffLegDeadlift)
        #expect(cue?.kind == .kneeBendIncreased)
        #expect(cue?.observation == "Your knees bent more during the last two hinges.")
        #expect(cue?.nextAction == "Try keeping a comfortable, similar knee bend through each hinge.")
    }

    @Test func changingRangeDoesNotConfusePostureWithRange() {
        let reps = (0 ..< 6).map { (index: Int) -> RepMetric in
            RepMetric(
                number: index + 1,
                startTime: Double(index) * 2,
                endTime: Double(index + 1) * 2,
                relativeRange: index >= 4 ? 60.0 : 80.0,
                postureValue: index >= 4 ? 35.0 : 10.0
            )
        }
        let analysis = SetAnalysis(
            reps: reps,
            confidence: 0.9,
            rubricVersion: ExerciseDefinition.staticLunge.rubricVersion
        )
        #expect(CueSelector.select(from: analysis, exercise: .staticLunge)?.kind == .rangeDecreased)
    }

    @Test func oldSavedRepWithoutPostureStillDecodes() throws {
        let json = Data(#"{"number":1,"startTime":0,"endTime":2,"normalizedHipTravel":0.4}"#.utf8)
        let rep = try JSONDecoder().decode(RepMetric.self, from: json)
        #expect(rep.relativeRange == 0.4)
        #expect(rep.postureValue == nil)
    }

    private func measured(_ outcome: AnalysisOutcome) throws -> SetAnalysis {
        guard case .analyzed(let analysis) = outcome else {
            throw TraceError.notMeasured
        }
        return analysis
    }
}
