import Foundation
import Testing
@testable import Plumb

struct SilhouetteCheckTests {
    /// A side-view standing person, normalized coordinates (top-left origin).
    private let joints: [BodyJoint: JointPoint] = [
        .leftShoulder: JointPoint(x: 0.50, y: 0.30, confidence: 0.6),
        .leftHip: JointPoint(x: 0.50, y: 0.55, confidence: 0.6),
        .leftKnee: JointPoint(x: 0.52, y: 0.72, confidence: 0.6),
        .leftAnkle: JointPoint(x: 0.50, y: 0.88, confidence: 0.5),
    ]

    /// A coarse 144 × 256 mask (Vision's fast quality) with a body 0.06 wide from `top` to `bottom`.
    private func mask(top: Double = 0.25, bottom: Double, centerX: Double = 0.5,
                      halfWidth: Double = 0.03) -> PersonMask {
        let width = 144
        let height = 256
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            let v = (Double(y) + 0.5) / Double(height)
            guard v >= top && v <= bottom else { continue }
            for x in 0..<width {
                let u = (Double(x) + 0.5) / Double(width)
                if abs(u - centerX) <= halfWidth { pixels[y * width + x] = 255 }
            }
        }
        return PersonMask(width: width, height: height, pixels: pixels)!
    }

    @Test func jointsOnTheSilhouetteAreSupported() {
        let verdict = SilhouetteCheck.verdict(for: joints, mask: mask(bottom: 0.90))
        #expect(verdict == .checked(supported: Set(joints.keys)))
    }

    @Test func anAnkleJustPastTheMasksThinEdgeStillCounts() {
        // Fast masks lose the last few pixels of a foot: the silhouette stops 1.5% of the frame
        // above the ankle point. The first version (two mask pixels) rejected this visible ankle.
        let verdict = SilhouetteCheck.verdict(for: joints, mask: mask(bottom: 0.865))
        #expect(verdict == .checked(supported: Set(joints.keys)))
    }

    @Test func anAnkleUnderACoverIsRejected() {
        // Like tools/replay/fixtures/squat-feet-hidden.mp4: everything below 78% of the height is
        // covered, about 6% of the frame above the ankle.
        let verdict = SilhouetteCheck.verdict(for: joints, mask: mask(bottom: 0.78))
        #expect(verdict == .checked(supported: [.leftShoulder, .leftHip, .leftKnee]))
    }

    @Test func aJointBesideTheBodyIsRejected() {
        var guessed = joints
        guessed[.leftWrist] = JointPoint(x: 0.80, y: 0.50, confidence: 0.7)
        guard case .checked(let supported) = SilhouetteCheck.verdict(for: guessed, mask: mask(bottom: 0.90)) else {
            Issue.record("Expected a checked verdict")
            return
        }
        #expect(!supported.contains(.leftWrist))
        #expect(supported.contains(.leftAnkle))
    }

    @Test func anEmptyMaskIsNoCheckRatherThanEveryJointHidden() {
        let empty = PersonMask(width: 144, height: 256, pixels: [UInt8](repeating: 0, count: 144 * 256))
        #expect(SilhouetteCheck.verdict(for: joints, mask: empty) == .unavailable)
        #expect(SilhouetteCheck.verdict(for: joints, mask: nil) == .unavailable)
    }

    @Test func maskSizeMustMatchItsPixels() {
        #expect(PersonMask(width: 10, height: 10, pixels: [0]) == nil)
        #expect(PersonMask(width: 0, height: 10, pixels: []) == nil)
    }
}
