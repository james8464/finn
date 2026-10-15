import Foundation
import Testing
@testable import Finn

struct FormFrameSelectionTests {
    @Test func anIsolatedHipSpikeCannotMoveTheFormWindow() throws {
        let frames = CaptureTraces.squats(reps: 3, from: 0)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .squat),
              let rep = analysis.reps.first,
              case .usable(let side) = EvidenceGate.assess(frames),
              let expected = ExerciseAnalyzer.deepestFrameIndex(of: rep, in: frames, as: .squat, side: side) else {
            Issue.record("Expected a measured fixture")
            return
        }
        let early = try #require(frames.firstIndex { $0.time > rep.startTime + 0.1 })
        var disturbed = frames
        var joints = frames[early].joints
        joints[JointRole.hip.joint(on: side)] = JointPoint(x: 0.47, y: 0.95, confidence: 0.99)
        disturbed[early] = PoseFrame(time: frames[early].time, subjectCount: 1, joints: joints)
        let selected = try #require(ExerciseAnalyzer.deepestFrameIndex(
            of: rep, in: disturbed, as: .squat, side: side))
        #expect(abs(frames[selected].time - frames[expected].time) <= 0.15)
    }

    @Test(arguments: [ExerciseDefinition.squat, .pushUp])
    func indexedRepExtremesMatchTheMeasuredFrames(definition: ExerciseDefinition) {
        var generator = SyntheticRandom(seed: 123)
        let frames = SyntheticExerciseMotion.sequence(
            label: definition.kind == .pushUp ? "push_up" : "squat",
            settings: .init(), using: &generator)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: definition),
              case .usable(let side) = EvidenceGate.assess(frames, requirement: definition.evidence) else {
            Issue.record("Fixture needs a usable measured set")
            return
        }
        for rep in analysis.reps {
            let expected = ExerciseAnalyzer.deepestFrame(of: rep, in: frames, as: definition)
            let index = ExerciseAnalyzer.deepestFrameIndex(of: rep, in: frames,
                                                           as: definition, side: side)
            #expect(index.map { frames[$0].time } == expected?.time)
            let window = FormChecks.bottomFrames(of: rep, in: frames,
                                                  definition: definition, side: side)
            #expect(window.contains(where: { $0.time == expected?.time }))
            #expect(window.count <= 5)
        }
    }

    @Test func flatBottomSelectsTheFirstFrame() {
        var generator = SyntheticRandom(seed: 123)
        let frames = SyntheticExerciseMotion.sequence(label: "squat", settings: .init(), using: &generator)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .squat),
              let rep = analysis.reps.first,
              case .usable(let side) = EvidenceGate.assess(frames, requirement: ExerciseDefinition.squat.evidence),
              let deepest = ExerciseAnalyzer.deepestFrame(of: rep, in: frames, as: .squat) else {
            Issue.record("Fixture needs a measured squat")
            return
        }
        let range = ExerciseAnalyzer.frameRange(from: rep.startTime, through: rep.endTime, in: frames)
        let flat = frames.enumerated().map { index, frame in
            range.contains(index) ? deepest.retimed(to: frame.time) : frame
        }
        #expect(ExerciseAnalyzer.deepestFrameIndex(of: rep, in: flat,
                                                   as: .squat, side: side) == range.lowerBound)
    }
}
