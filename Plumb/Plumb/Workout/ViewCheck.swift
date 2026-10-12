import Foundation
import simd

/// Camera-angle check from Vision 3D body pose (`VNDetectHumanBodyPose3DRequest`). It refuses
/// a set filmed from the front or at an angle when the rubric needs a side view. When no 3D
/// estimate is available, it does not decide, and the 2D visibility rules apply alone.
/// The threshold is a starting value: it has not been measured on real sets.
nonisolated enum ViewCheck {
    /// Largest median deviation from a true profile still treated as a side view.
    static let maximumSideDeviationDegrees = 30.0
    /// Fewer 3D estimates than this over a set means the check could not run.
    static let minimumSetEstimates = 4
    /// Recent estimates needed before the framing screen asks the person to turn.
    static let minimumPreviewEstimates = 3

    enum Verdict: Equatable {
        case matches(medianDeviation: Double, estimates: Int)
        case mismatch(medianDeviation: Double, estimates: Int)
        case unavailable
    }

    /// Degrees between the body's left-right axis and the camera's line of sight to the hips.
    /// 0 is a true side view; 90 means the person faces the camera or turns away from it.
    /// Positions are camera-relative, in meters, as Vision 3D pose returns them. Left and right
    /// labels may be swapped without changing the result.
    static func profileDeviation(leftHip: SIMD3<Double>, rightHip: SIMD3<Double>,
                                 leftShoulder: SIMD3<Double>? = nil,
                                 rightShoulder: SIMD3<Double>? = nil) -> Double? {
        let hips = leftHip - rightHip
        guard simd_length(hips) > 1e-4 else { return nil }
        var lateral = simd_normalize(hips)
        if let leftShoulder, let rightShoulder, simd_length(leftShoulder - rightShoulder) > 1e-4 {
            var shoulders = simd_normalize(leftShoulder - rightShoulder)
            if simd_dot(shoulders, lateral) < 0 { shoulders = -shoulders }
            lateral = simd_normalize(lateral + shoulders)
        }
        let sight = (leftHip + rightHip) / 2
        guard simd_length(sight) > 1e-4 else { return nil }
        let cosine = abs(simd_dot(lateral, simd_normalize(sight)))
        return acos(min(1, cosine)) * 180 / .pi
    }

    static func assess(_ frames: [PoseFrame], expected: ExpectedView) -> Verdict {
        let deviations = frames.compactMap(\.profileDeviationDegrees)
        guard deviations.count >= minimumSetEstimates else { return .unavailable }
        let median = median(deviations)
        return fits(median, expected: expected)
            ? .matches(medianDeviation: median, estimates: deviations.count)
            : .mismatch(medianDeviation: median, estimates: deviations.count)
    }

    /// True when the latest estimates agree the person is not in the expected view.
    static func previewAsksToTurn(_ recentDeviations: [Double], expected: ExpectedView) -> Bool {
        guard recentDeviations.count >= minimumPreviewEstimates else { return false }
        return !fits(median(recentDeviations), expected: expected)
    }

    private static func fits(_ deviation: Double, expected: ExpectedView) -> Bool {
        switch expected {
        case .side: deviation <= maximumSideDeviationDegrees
        }
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
