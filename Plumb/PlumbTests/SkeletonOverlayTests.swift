import CoreGraphics
import Foundation
import Testing
@testable import Plumb

struct SkeletonOverlayTests {
    /// a side-on squatter in a portrait frame (height / width = 16 / 9), knee bent to 90°
    private func squatFrame(kneeConfidence: Double = 0.9, aspectRatio: Double = 16.0 / 9) -> PoseFrame {
        // thigh horizontal, shin vertical once y is scaled by the aspect ratio, as the angle is
        let knee = (x: 0.5, y: 0.7)
        let hip = (x: knee.x - 0.2, y: knee.y)
        let ankle = (x: knee.x, y: knee.y + 0.2 / aspectRatio * 1)
        return PoseFrame(time: 0, subjectCount: 1, joints: [
            .leftHip: JointPoint(x: hip.x, y: hip.y, confidence: 0.9),
            .leftKnee: JointPoint(x: knee.x, y: knee.y, confidence: kneeConfidence),
            .leftAnkle: JointPoint(x: ankle.x, y: ankle.y, confidence: 0.9),
            .leftShoulder: JointPoint(x: 0.3, y: 0.4, confidence: 0.9),
            .rightHip: JointPoint(x: 0.31, y: 0.7, confidence: 0.2),
        ], aspectRatio: aspectRatio)
    }

    @Test func portraitFrameFitsTheScreenHeightAndKeepsItsShape() {
        let rect = SkeletonGeometry.imageRect(aspectRatio: 16.0 / 9, in: CGSize(width: 400, height: 800))
        #expect(abs(rect.width - 400) < 0.001)
        #expect(abs(rect.height - 400 * 16 / 9) < 0.001)
        #expect(abs(rect.midY - 400) < 0.001)
    }

    @Test func landscapeFrameIsLetterboxedInAPortraitScreen() {
        let rect = SkeletonGeometry.imageRect(aspectRatio: 9.0 / 16, in: CGSize(width: 400, height: 800))
        #expect(abs(rect.width - 400) < 0.001)
        #expect(abs(rect.height - 225) < 0.001)
        #expect(abs(rect.minY - (800 - 225) / 2) < 0.001)
    }

    @Test func mirroredPictureFlipsTheSkeletonLeftToRight() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 200)
        let plain = SkeletonGeometry.viewPoint(x: 0.25, y: 0.5, in: rect, mirrored: false)
        let mirrored = SkeletonGeometry.viewPoint(x: 0.25, y: 0.5, in: rect, mirrored: true)
        #expect(plain == CGPoint(x: 35, y: 120))
        #expect(mirrored == CGPoint(x: 85, y: 120))
    }

    @Test func squatShowsTheKneeAngleBesideTheKnee() throws {
        let size = CGSize(width: 390, height: 844)
        let geometry = SkeletonGeometry(frame: squatFrame(), exercise: .squat, size: size, mirrored: false)
        let angle = try #require(geometry.angle)
        #expect(abs(angle.degrees - 90) <= 1, "knee angle \(angle.degrees)")
        #expect(angle.text.hasPrefix("Knee "))
        #expect(angle.reliable)
        let rect = SkeletonGeometry.imageRect(aspectRatio: 16.0 / 9, in: size)
        #expect(angle.vertex == SkeletonGeometry.viewPoint(x: 0.5, y: 0.7, in: rect, mirrored: false))
    }

    @Test func pushUpShowsTheElbow() {
        let frame = PoseFrame(time: 0, subjectCount: 1, joints: [
            .rightShoulder: JointPoint(x: 0.4, y: 0.5, confidence: 0.8),
            .rightElbow: JointPoint(x: 0.45, y: 0.6, confidence: 0.8),
            .rightWrist: JointPoint(x: 0.4, y: 0.7, confidence: 0.8),
        ], aspectRatio: 1)
        let geometry = SkeletonGeometry(frame: frame, exercise: .pushUp,
                                        size: CGSize(width: 300, height: 300), mirrored: false)
        #expect(geometry.angle?.text.hasPrefix("Elbow ") == true)
    }

    @Test func pointsTheAnalysisWouldIgnoreAreMarked() throws {
        let geometry = SkeletonGeometry(frame: squatFrame(kneeConfidence: 0.2), exercise: .squat,
                                        size: CGSize(width: 390, height: 844), mirrored: false)
        let knee = try #require(geometry.joints.first { $0.joint == .leftKnee })
        #expect(!knee.reliable)
        #expect(geometry.joints.first { $0.joint == .leftHip }?.reliable == true)
        #expect(geometry.angle?.reliable == false)
        // hip to knee and knee to ankle use the unclear knee; the hip line uses the weak right hip
        #expect(geometry.bones.filter { !$0.reliable }.count == 3)
        #expect(geometry.summary.hasPrefix("5 joints, 3 clear"))
    }

    @Test func theSideVisionIsSurerOfCarriesTheAngle() {
        var joints = squatFrame().joints
        joints[.rightHip] = JointPoint(x: 0.3, y: 0.7, confidence: 0.95)
        joints[.rightKnee] = JointPoint(x: 0.5, y: 0.75, confidence: 0.95)
        joints[.rightAnkle] = JointPoint(x: 0.5, y: 0.9, confidence: 0.95)
        let frame = PoseFrame(time: 0, subjectCount: 1, joints: joints, aspectRatio: 16.0 / 9)
        #expect(SkeletonGeometry.trackedSide(frame, roles: [.hip, .knee, .ankle]) == .right)
    }

    @Test func screenRotationIsWhatTheFrameStillNeeds() {
        // portrait: frames are already turned like the screen
        #expect(PreviewFeed.displayRotation(capture: 90, preview: 90) == 0)
        // phone sideways, interface still portrait: a quarter turn either way
        #expect(PreviewFeed.displayRotation(capture: 0, preview: 90) == 90)
        #expect(PreviewFeed.displayRotation(capture: 180, preview: 90) == 270)
        #expect(PreviewFeed.displayRotation(capture: 270, preview: 0) == 90)
        // small sensor jitter rounds to the nearest quarter turn
        #expect(PreviewFeed.displayRotation(capture: 88, preview: 91) == 0)
    }

    @Test func theMirroredFrontCameraTurnsLikeTheBackCameraForTheSamePhonePosition() {
        // portrait is unchanged
        #expect(PreviewFeed.displayRotation(capture: 90, preview: 90, mirrored: true) == 0)
        // phone on its side, interface portrait: the front camera's upright frame needs the same turn
        // as the back camera's (capture 0, preview 90 gives 90), not the opposite one
        #expect(PreviewFeed.displayRotation(capture: 180, preview: 90, mirrored: true) == 90)
        #expect(PreviewFeed.displayRotation(capture: 0, preview: 90, mirrored: true) == 270)
        // a portrait-mounted front sensor (preview 0) on its side
        #expect(PreviewFeed.displayRotation(capture: 90, preview: 0, mirrored: true) == 90)
    }
}
