import Foundation
import Testing
@testable import Plumb

/// A capture on a real phone: walk from the phone to the spot, do the set, walk back to stop.
nonisolated struct SetWindowTests {
    @Test func walkingInAndOutNoLongerRefusesTheSet() {
        let capture = CaptureTraces.walkIn() + CaptureTraces.squats(reps: 6, from: 2.0) + CaptureTraces.walkOut(from: 14.0)
        // Before the set window, these frames were refused: the legs were out of view for over a second.
        #expect(EvidenceGate.assess(capture, requirement: .squat).isRejected)

        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(capture, as: .squat) else {
            Issue.record("Expected the set between walking in and out to be measured")
            return
        }
        #expect(analysis.reps.count == 6)
    }

    @Test func theWindowStartsWhenTheAthleteSettlesAndEndsWhenTheyLeave() {
        let capture = CaptureTraces.walkIn() + CaptureTraces.squats(reps: 6, from: 2.0) + CaptureTraces.walkOut(from: 14.0)
        let set = SetWindow.active(capture, requirement: .squat)
        let start = set.first?.time ?? 0
        let end = set.last?.time ?? 0
        #expect(start >= 1.7 && start <= 2.2)
        #expect(end >= 13.8 && end <= 14.4)
        #expect(EvidenceGate.assess(set, requirement: .squat) == .usable(.left))
    }

    @Test func aSetThatStartsInPositionIsLeftAsItIs() {
        let set = CaptureTraces.squats(reps: 6, from: 0)
        #expect(SetWindow.activeRange(set, requirement: .squat) == nil)
        #expect(SetWindow.active(set, requirement: .squat) == set)
    }

    @Test func trimmingTwiceChangesNothing() {
        let capture = CaptureTraces.walkIn() + CaptureTraces.squats(reps: 6, from: 2.0) + CaptureTraces.walkOut(from: 14.0)
        let once = SetWindow.active(capture, requirement: .squat)
        #expect(SetWindow.active(once, requirement: .squat) == once)
    }

    @Test func noTimeInPositionKeepsTheWholeCaptureSoTheGateExplainsIt() {
        // Legs never in view: nothing to trim to, and the refusal still names the missing joints.
        let capture = (0..<150).map { index in
            CaptureTraces.frame(time: Double(index) * CaptureTraces.step, hipY: 0.42, ankleX: 0.51, legs: false)
        }
        #expect(SetWindow.active(capture, requirement: .squat) == capture)
        #expect(EvidenceGate.assess(capture, requirement: .squat) == .reject(.missingJoints))
    }

    @Test func aBriefMomentInPositionIsNotASet() {
        // In position for one second only: shorter than a set, so nothing is trimmed.
        let capture = CaptureTraces.walkIn() + CaptureTraces.squats(reps: 0, from: 2.0, standing: 1.0) + CaptureTraces.walkOut(from: 3.0)
        #expect(SetWindow.activeRange(capture, requirement: .squat) == nil)
    }

    @Test func aGapInsideTheSetStillCounts() {
        var capture = CaptureTraces.walkIn() + CaptureTraces.squats(reps: 6, from: 2.0) + CaptureTraces.walkOut(from: 14.0)
        // Legs hidden for 1.5 s in the middle of the set.
        capture = capture.map { frame in
            guard frame.time > 7.0 && frame.time < 8.5 else { return frame }
            return CaptureTraces.frame(time: frame.time, hipY: frame.joints[.leftHip]?.y ?? 0.42, ankleX: 0.51, legs: false)
        }
        guard case .insufficientView = ExerciseAnalyzer.analyze(capture, as: .squat) else {
            Issue.record("A 1.5 s gap inside the set must still refuse it")
            return
        }
    }

    @Test func pushUpGettingDownAndStandingUpIsTrimmed() {
        // Walk in standing (wrists by the hips), get down, six push-ups, stand up and leave.
        var capture: [PoseFrame] = []
        var time = 0.0
        while time < 2.0 {
            let progress = time / 2.0
            capture.append(CaptureTraces.pushUpFrame(time: time, elbowBend: 0, wristX: 0.2 + 0.1 * progress, wristY: 0.55))
            time += CaptureTraces.step
        }
        for _ in 0..<6 {
            var t = 0.0
            while t < 2.0 {
                let bend = 70 * (1 - cos(2 * .pi * t / 2.0)) / 2
                capture.append(CaptureTraces.pushUpFrame(time: time, elbowBend: bend, wristX: 0.62, wristY: 0.86))
                t += CaptureTraces.step
                time += CaptureTraces.step
            }
        }
        let end = time
        while time < end + 2.0 {
            let progress = (time - end) / 2.0
            capture.append(CaptureTraces.pushUpFrame(time: time, elbowBend: 0, wristX: 0.62 - 0.3 * progress,
                                       wristY: 0.86 - 0.3 * progress))
            time += CaptureTraces.step
        }
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(capture, as: .pushUp) else {
            Issue.record("Expected the push-ups between getting down and standing up to be measured")
            return
        }
        #expect(analysis.reps.count == 6)
    }
}

/// Frame traces of a capture filmed the way people use the phone, shared with the session tests.
nonisolated enum CaptureTraces {
    static let step = 1.0 / 15


    /// One second with the legs out of view (close to the phone), then one second walking into place.
    static func walkIn() -> [PoseFrame] {
        var frames: [PoseFrame] = []
        var time = 0.0
        while time < 2.0 - step / 2 {
            if time < 1.0 {
                frames.append(frame(time: time, hipY: 0.5, ankleX: 0.2, legs: false))
            } else {
                frames.append(frame(time: time, hipY: 0.42, ankleX: 0.15 + 0.36 * (time - 1.0), legs: true))
            }
            time += step
        }
        return frames
    }

    /// Reps of two seconds each, hips 0.20 of the frame down at the bottom.
    static func squats(reps: Int, from start: Double, standing: Double = 0) -> [PoseFrame] {
        var frames: [PoseFrame] = []
        var time = 0.0
        let duration = Double(reps) * 2.0 + standing
        while time <= duration + step / 2 {
            let phase = time < Double(reps) * 2.0 ? time.truncatingRemainder(dividingBy: 2.0) / 2.0 : 0
            let hipY = 0.42 + 0.20 * (1 - cos(2 * .pi * phase)) / 2
            frames.append(frame(time: start + time, hipY: hipY, ankleX: 0.51, legs: true))
            time += step
        }
        return frames
    }

    /// Walking back toward the phone: the feet slide across the frame, then the legs leave the picture.
    static func walkOut(from start: Double, duration: Double = 2.5) -> [PoseFrame] {
        var frames: [PoseFrame] = []
        var time = step
        while time < duration {
            if time < 1.0 {
                frames.append(frame(time: start + time, hipY: 0.42, ankleX: 0.51 + 0.3 * time, legs: true))
            } else {
                frames.append(frame(time: start + time, hipY: 0.55, ankleX: 0.9, legs: false))
            }
            time += step
        }
        return frames
    }

    static func frame(time: Double, hipY: Double, ankleX: Double, legs: Bool) -> PoseFrame {
        var joints: [BodyJoint: JointPoint] = [
            .leftHip: JointPoint(x: ankleX - 0.04, y: hipY, confidence: 0.6),
            .leftShoulder: JointPoint(x: ankleX - 0.05, y: hipY - 0.25, confidence: 0.6),
            .rightHip: JointPoint(x: ankleX + 0.02, y: hipY, confidence: 0.2),
            .rightShoulder: JointPoint(x: ankleX + 0.01, y: hipY - 0.25, confidence: 0.2),
        ]
        if legs {
            joints[.leftKnee] = JointPoint(x: ankleX - 0.02, y: 0.70, confidence: 0.6)
            joints[.leftAnkle] = JointPoint(x: ankleX, y: 0.90, confidence: 0.6)
            joints[.rightKnee] = JointPoint(x: ankleX + 0.04, y: 0.70, confidence: 0.2)
            joints[.rightAnkle] = JointPoint(x: ankleX + 0.06, y: 0.90, confidence: 0.2)
        }
        return PoseFrame(time: time, subjectCount: 1, joints: joints, athleteTracking: .tracked)
    }

    /// Side view of a push-up: forearm upright on the planted wrist, the upper arm turning about the
    /// elbow so the elbow angle is 180° minus `elbowBend`.
    static func pushUpFrame(time: Double, elbowBend: Double, wristX: Double, wristY: Double) -> PoseFrame {
        let bend = elbowBend * .pi / 180
        let elbow = (x: wristX, y: wristY - 0.12)
        let shoulder = (x: elbow.x + 0.12 * sin(bend), y: elbow.y - 0.12 * cos(bend))
        return PoseFrame(time: time, subjectCount: 1, joints: [
            .leftWrist: JointPoint(x: wristX, y: wristY, confidence: 0.6),
            .leftElbow: JointPoint(x: elbow.x, y: elbow.y, confidence: 0.6),
            .leftShoulder: JointPoint(x: shoulder.x, y: shoulder.y, confidence: 0.6),
            .leftHip: JointPoint(x: shoulder.x - 0.25, y: shoulder.y + 0.02, confidence: 0.6),
        ], athleteTracking: .tracked)
    }
}
