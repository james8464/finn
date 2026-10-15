import CoreGraphics
import Foundation
import Testing
@testable import Finn

struct RepExtremesAndHintTests {
    /// Six squats, 2 s each, with depths growing then shrinking: rep 3 deepest, rep 6 shallowest.
    private func varyingSquat() -> [PoseFrame] {
        let depths = [0.18, 0.22, 0.26, 0.24, 0.20, 0.16]
        return (0...(6 * 20)).map { index in
            let rep = min(index / 20, 5)
            let phase = Double(index % 20) / 20
            let hipY = 0.42 + depths[rep] * (1 - cos(2 * .pi * phase)) / 2
            return squatFrame(time: Double(index) * 0.1, hipY: hipY)
        }
    }

    @Test func deepestAndShallowestRepsAreDrawnFromTheirLowestFrame() throws {
        let frames = varyingSquat()
        guard case .analyzed(let analysis) = SquatAnalyzer.analyze(frames) else {
            Issue.record("The set must be measured")
            return
        }
        let extremes = try #require(RepExtremes.make(analysis, frames: frames, definition: .squat))
        #expect(extremes.deepest.number == 3)
        #expect(extremes.shallowest.number == 6)
        // The frame drawn is the bottom of the rep: hips at their lowest for that rep.
        let bottom = try #require(extremes.deepest.frame.joints[.leftHip]?.y)
        #expect(abs(bottom - (0.42 + 0.26)) < 0.02)
    }

    @Test func noExtremesForOneRepOrEqualReps() {
        let single = SetAnalysis(reps: [RepMetric(number: 1, startTime: 0, endTime: 2, relativeRange: 0.3)],
                                 confidence: 0.9, rubricVersion: "squat-side-v4")
        #expect(RepExtremes.make(single, frames: varyingSquat(), definition: .squat) == nil)
    }

    @Test func croppingKeepsTheJointAngle() throws {
        let frame = PoseFrame(time: 0, subjectCount: 1, joints: [
            .leftHip: JointPoint(x: 0.30, y: 0.70, confidence: 0.9),
            .leftKnee: JointPoint(x: 0.50, y: 0.70, confidence: 0.9),
            .leftAnkle: JointPoint(x: 0.50, y: 0.70 + 0.2 / (16.0 / 9), confidence: 0.9),
        ], aspectRatio: 16.0 / 9)
        let cropped = try #require(SkeletonGeometry.cropped(frame))
        let original = SkeletonGeometry(frame: frame, exercise: .squat, size: CGSize(width: 300, height: 600), mirrored: false)
        let reframed = SkeletonGeometry(frame: cropped, exercise: .squat, size: CGSize(width: 150, height: 180), mirrored: false)
        #expect(original.angle?.degrees == reframed.angle?.degrees)
        #expect(cropped.joints.values.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }

    @Test func framingNamesTheJointThatIsNotClear() {
        let hipsUnclear = (0..<5).map { index in
            squatFrame(time: Double(index) * 0.1, hipY: 0.42, confidence: 0.9)
        }.map { frame -> PoseFrame in
            var joints = frame.joints
            joints[.leftHip] = JointPoint(x: 0.47, y: 0.42, confidence: 0.15)
            joints[.rightHip] = JointPoint(x: 0.53, y: 0.42, confidence: 0.1)
            return PoseFrame(time: frame.time, subjectCount: 1, joints: joints)
        }
        #expect(EvidenceGate.previewStatus(hipsUnclear) == .adjustPosition)
        #expect(EvidenceGate.unclearJoint(hipsUnclear) == .hip)
        let clear = (0..<5).map { squatFrame(time: Double($0) * 0.1, hipY: 0.42) }
        #expect(EvidenceGate.unclearJoint(clear) == nil)
        #expect(EvidenceGate.unclearJoint([]) == nil)
    }
}
