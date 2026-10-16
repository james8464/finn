import Foundation
import Testing
@testable import Finn

/// Squats filmed the way a jury tries the app (15 October 2026, Guilhem's iPhone): facing the phone,
/// the phone on the floor tilted up so the feet sit at the picture's edge, turning from the front to
/// the side, stepping out of the picture and back. The traces are synthetic; their shapes follow the
/// screen recording of that morning, where the live count froze at 3 while the squats went on.
nonisolated enum JuryTraces {
    static let step = 1.0 / 15

    /// A person facing the phone: both hips and both shoulders, 0.25 of the picture apart, and the
    /// knees and ankles only when `legs`. `down` is the share of a rep's depth (0 standing, 1 bottom),
    /// with the hips 0.20 of the picture down at the bottom.
    static func front(
        time: Double,
        down: Double,
        legs: Bool,
        x: Double = 0.5,
        hips: Bool = true
    ) -> PoseFrame {
        let hipY = 0.45 + 0.20 * down
        var joints: [BodyJoint: JointPoint] = [
            .leftShoulder: JointPoint(x: x - 0.08, y: hipY - 0.25 + 0.05 * down, confidence: 0.7),
            .rightShoulder: JointPoint(x: x + 0.08, y: hipY - 0.25 + 0.05 * down, confidence: 0.7),
            .nose: JointPoint(x: x, y: hipY - 0.33, confidence: 0.8),
        ]
        if hips {
            joints[.leftHip] = JointPoint(x: x - 0.05, y: hipY, confidence: 0.5)
            joints[.rightHip] = JointPoint(x: x + 0.05, y: hipY, confidence: 0.5)
        }
        if legs {
            joints[.leftKnee] = JointPoint(x: x - 0.06, y: 0.72, confidence: 0.5)
            joints[.rightKnee] = JointPoint(x: x + 0.06, y: 0.72, confidence: 0.5)
            joints[.leftAnkle] = JointPoint(x: x - 0.06, y: 0.92, confidence: 0.5)
            joints[.rightAnkle] = JointPoint(x: x + 0.06, y: 0.92, confidence: 0.5)
        }
        return PoseFrame(
            time: time,
            subjectCount: 1,
            joints: joints,
            aspectRatio: 1,
            athleteTracking: .tracked
        )
    }

    /// Nobody in the picture: the athlete stepped out of it.
    static func empty(time: Double) -> PoseFrame {
        PoseFrame(time: time, subjectCount: 0, joints: [:], aspectRatio: 1, athleteTracking: .hidden)
    }

    /// `reps` squats of two seconds from `start`, then `standing` seconds still.
    static func squats(
        reps: Int,
        from start: Double,
        standing: Double = 1,
        legs: Bool = false,
        x: Double = 0.5,
        hidesHipsAtTheBottom: Bool = false
    ) -> [PoseFrame] {
        let duration = Double(reps) * 2 + standing
        return stride(from: 0.0, to: duration, by: step).map { time in
            let phase = time < Double(reps) * 2 ? time.truncatingRemainder(dividingBy: 2) / 2 : 0
            let down = (1 - cos(2 * .pi * phase)) / 2
            return front(
                time: start + time,
                down: down,
                legs: legs,
                x: x,
                hips: !(hidesHipsAtTheBottom && down > 0.7)
            )
        }
    }

    static func gap(from start: Double, seconds: Double) -> [PoseFrame] {
        stride(from: 0.0, to: seconds, by: step).map { empty(time: start + $0) }
    }
}

nonisolated struct HipCountTests {
    private func count(_ frames: [PoseFrame]) -> (reps: Int, version: String)? {
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .squat) else {
            return nil
        }
        return (analysis.reps.count, analysis.rubricVersion)
    }

    @Test func aFrontSquatWithTheFeetOutOfViewIsCountedFromTheHips() throws {
        let frames = JuryTraces.squats(reps: 6, from: 0)
        // the side rubric needs the knee and ankle: it refused this set.
        #expect(EvidenceGate.assess(frames, requirement: .squat).isRejected)
        let (outcome, diagnostics) = ExerciseAnalyzer.analyseWithDiagnostics(frames, as: .squat)
        guard case .analyzed(let analysis) = outcome else {
            Issue.record("Expected the squats to be counted from the hips")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(analysis.rubricVersion == ExerciseDefinition.squatTrunk.rubricVersion)
        // Counted, not advised: no posture reading and no posture observation.
        #expect(analysis.reps.allSatisfy { $0.postureValue == nil })
        #expect(CueSelector.select(from: analysis)?.kind != .torsoTiltIncreased)
        let note = try #require(diagnostics?.explanation(for: .squat, counted: 6))
        #expect(note.contains("counted the squats from your hips"))
    }

    @Test func theShouldersStandInWhenTheHipsAreLostAtTheBottom() {
        #expect(count(JuryTraces.squats(reps: 6, from: 0, hidesHipsAtTheBottom: true))?.reps == 6)
    }

    @Test func aTinySubjectCannotUseTheHipOnlyCount() {
        let frames = JuryTraces.squats(reps: 6, from: 0).map { frame in
            let joints = frame.joints.mapValues { point in
                JointPoint(
                    x: 0.5 + (point.x - 0.5) * 0.25,
                    y: 0.5 + (point.y - 0.5) * 0.25,
                    confidence: point.confidence
                )
            }
            return PoseFrame(
                time: frame.time,
                subjectCount: 1,
                joints: joints,
                aspectRatio: frame.aspectRatio,
                athleteTracking: .tracked
            )
        }
        #expect(count(frames) == nil)
    }

    /// The athlete steps out of the picture for two and a half seconds between reps.
    @Test func steppingOutOfViewKeepsTheRepsOnEitherSide() {
        let frames = JuryTraces.squats(reps: 3, from: 0) + JuryTraces.gap(from: 7, seconds: 2.5)
            + JuryTraces.squats(reps: 3, from: 9.5, x: 0.3)
        #expect(count(frames)?.reps == 6)
    }

    @Test func aClearSideViewSetKeepsTheSideRubricAndItsAdvice() {
        #expect(count(CaptureTraces.squats(reps: 6, from: 0))?.version == ExerciseDefinition.squat
            .rubricVersion)
    }

    @Test func standingStillIsNotASquat() {
        let frames = stride(from: 0.0, to: 10, by: JuryTraces.step).map {
            JuryTraces.front(time: $0, down: 0.05 * sin($0 * 9), legs: false)
        }
        #expect(count(frames) == nil)
    }

    /// Bobbing a few centimetres, well under a shallow squat, is not counted.
    @Test func aSmallBobIsNotASquat() {
        let frames = stride(from: 0.0, to: 12, by: JuryTraces.step).map { time in
            JuryTraces.front(time: time, down: 0.3 * (1 - cos(2 * .pi * time / 2)) / 2, legs: false)
        }
        #expect(count(frames) == nil)
    }

    /// Walking up to the phone on the floor and reaching for it: the torso grows in the picture as
    /// the hips drop. That is the set ending, not a squat.
    @Test func reachingForThePhoneIsNotASquat() {
        let squats = JuryTraces.squats(reps: 4, from: 0)
        let reach = stride(from: 0.0, to: 2.0, by: JuryTraces.step).map { time -> PoseFrame in
            let near = min(1, time / 1.2)
            let torso = 0.25 * (1 + 1.5 * near)
            let hipY = 0.45 + 0.35 * near
            return PoseFrame(time: 9 + time, subjectCount: 1, joints: [
                .leftHip: JointPoint(x: 0.45, y: hipY, confidence: 0.5),
                .rightHip: JointPoint(x: 0.55, y: hipY, confidence: 0.5),
                .leftShoulder: JointPoint(x: 0.42, y: hipY - torso, confidence: 0.7),
                .rightShoulder: JointPoint(x: 0.58, y: hipY - torso, confidence: 0.7),
            ], aspectRatio: 1, athleteTracking: .tracked)
        }
        #expect(count(squats + reach)?.reps == 4)
    }

    @Test func otherExercisesDoNotFallBackToTheHips() {
        #expect({
            if
                case .analyzed = ExerciseAnalyzer.analyse(
                    JuryTraces.squats(reps: 6, from: 0),
                    as: .staticLunge
                ) {
                return false
            }
            return true
        }())
    }
}

nonisolated struct LiveCountRecoveryTests {
    private func liveCount(_ frames: [PoseFrame]) -> Int {
        var monitor = LiveSetMonitor(definition: .squat)
        var seen: [PoseFrame] = []
        for frame in frames {
            seen.append(frame)
            _ = monitor.update(with: seen)
        }
        return monitor.countedReps
    }

    /// Three squats with the legs in view, then four after turning, the knees and ankles lost. The
    /// whole set so far fell under the 65% the side rubric needs, and the count froze at 3.
    @Test func theCountGoesOnAfterTheLegsAreLost() {
        let frames = JuryTraces.squats(reps: 3, from: 0, standing: 0, legs: true)
            + JuryTraces.squats(reps: 4, from: 6)
        #expect(liveCount(frames) == 7)
    }

    /// Out of the picture for two and a half seconds, then back a step to the side: a gap longer than
    /// the 0.75 s the side rubric allows refused the set so far, and nothing more was counted.
    @Test func theCountResumesAfterTheAthleteStepsOutAndBack() {
        let frames = JuryTraces.squats(reps: 3, from: 0, legs: true) + JuryTraces.gap(from: 7, seconds: 2.5)
            + JuryTraces.squats(reps: 3, from: 9.5, legs: true, x: 0.4)
        #expect(liveCount(frames) == 6)
    }

    /// The live count and the result agree on the same capture.
    @Test func theResultCountsWhatTheLiveCountSaid() {
        let frames = JuryTraces.squats(reps: 3, from: 0, standing: 0, legs: true)
            + JuryTraces.squats(reps: 4, from: 6)
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyse(frames, as: .squat) else {
            Issue.record("Expected the set to be measured")
            return
        }
        #expect(analysis.reps.count == liveCount(frames))
    }
}

nonisolated struct SetWindowSideTests {
    /// In position with the left side followed, then turned: the left hip is unclear, the right one
    /// clear at the same place. The athlete is still at their spot, not unseen.
    @Test func turningKeepsTheAthleteAtTheirSpot() throws {
        let inPosition = CaptureTraces.squats(reps: 0, from: 0, standing: 2)
        let turned = stride(from: 2.0 + CaptureTraces.step, to: 4, by: CaptureTraces.step).map { time in
            PoseFrame(time: time, subjectCount: 1, joints: [
                .leftHip: JointPoint(x: 0.47, y: 0.42, confidence: 0.1),
                .rightHip: JointPoint(x: 0.49, y: 0.42, confidence: 0.6),
                .rightShoulder: JointPoint(x: 0.48, y: 0.17, confidence: 0.6),
            ], athleteTracking: .tracked)
        }
        let spots = try #require(SetWindow.spots(inPosition + turned, requirement: .squat))
        #expect(spots.suffix(turned.count).allSatisfy { $0 == .atSpot })
    }
}

nonisolated struct AthleteRelocationTests {
    private func person(x: Double) -> [BodyJoint: JointPoint] {
        [
            .leftShoulder: JointPoint(x: x - 0.02, y: 0.3, confidence: 0.9),
            .leftHip: JointPoint(x: x - 0.02, y: 0.6, confidence: 0.9),
            .leftKnee: JointPoint(x: x, y: 0.75, confidence: 0.9),
            .leftAnkle: JointPoint(x: x + 0.02, y: 0.9, confidence: 0.9),
            .rightHip: JointPoint(x: x + 0.02, y: 0.6, confidence: 0.9),
        ]
    }

    /// During a set the athlete walks out of the picture and comes back a metre to the side. Before,
    /// they were never followed again and only a new set counted.
    @Test func aLockedTrackerFindsTheAthleteBackAfterTheyStepOutOfView() {
        var tracker = AthleteTracker()
        #expect(tracker.select([person(x: 0.5)], aspectRatio: 1, time: 0) == 0)
        tracker.lock()
        for tenth in 1 ... 14 {
            #expect(tracker.select([], aspectRatio: 1, time: Double(tenth) / 10) == nil)
        }
        // back at another place, soon after: not yet taken for the athlete.
        #expect(tracker.select([person(x: 0.2)], aspectRatio: 1, time: 1.5) == nil)
        // Once `relocateAfter` has passed, the lone person is the athlete again, and then followed.
        #expect(tracker
            .select([person(x: 0.2)], aspectRatio: 1, time: AthleteTracker.relocateAfter + 0.1) == 0)
        #expect(tracker
            .select([person(x: 0.21)], aspectRatio: 1, time: AthleteTracker.relocateAfter + 0.2) == 0)
        #expect(tracker.isLocked)
    }

    /// Two people in view after the athlete came back: Finn cannot tell which one is them, and waits.
    @Test func withSomeoneElseInViewTheTrackerStillWaits() {
        var tracker = AthleteTracker()
        _ = tracker.select([person(x: 0.5)], aspectRatio: 1, time: 0)
        tracker.lock()
        for tenth in 1 ... 20 {
            _ = tracker.select([], aspectRatio: 1, time: Double(tenth) / 10)
        }
        #expect(tracker.select([person(x: 0.2), person(x: 0.8)], aspectRatio: 1, time: 3) == nil)
    }
}
