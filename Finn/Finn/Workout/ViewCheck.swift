import Foundation
import simd

/// Camera-angle check from Vision 3D body pose (`VNDetectHumanBodyPose3DRequest`). It never
/// stops a set from being counted: away from a side view the reps are counted without posture
/// advice, and the framing screen and the result say to turn. Until 15 October a person facing
/// the camera for several seconds had the whole set refused. When no 3D estimate is available,
/// it does not decide, and the 2D visibility rules apply alone.
nonisolated enum ViewCheck {
    /// Largest median deviation from a true profile still treated as a side view. Above it, the
    /// framing screen and the result suggest turning a little; the set is still measured.
    static let maximumSideDeviationDegrees = 30.0
    /// From this median deviation a set counts as filmed from the front (said so in the result). Measured on 150 public
    /// gym videos (Mendeley, 12 October 2026): video medians were 85° for front views (all 50 at
    /// 75° or more), 48° for diagonal views, and 21° for side views (none at 75°).
    static let clearlyFrontDegrees = 75.0
    /// A set counts as filmed from the front only when its estimates span at least this long.
    static let minimumFrontDuration: TimeInterval = 3
    /// Fewer 3D estimates than this over a set means the check could not run.
    static let minimumSetEstimates = 4
    /// Recent estimates needed before the framing screen asks the person to turn.
    static let minimumPreviewEstimates = 3

    enum Verdict: Equatable {
        case matches(medianDeviation: Double, estimates: Int)
        /// Not side-on, but not clearly and lastingly frontal either: measured, with a suggestion.
        case angled(medianDeviation: Double, estimates: Int)
        /// Clearly frontal for at least `minimumFrontDuration`: counted, without posture advice.
        case mismatch(medianDeviation: Double, estimates: Int)
        case unavailable

        var isMismatch: Bool {
            if case .mismatch = self { return true }
            return false
        }
    }

    /// Degrees between the body's left-right axis and the camera's line of sight to the hips.
    /// 0 is a true side view; 90 means the person faces the camera or turns away from it.
    /// Positions are camera-relative, in metres, as Vision 3D pose returns them. Left and right
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
        let estimates = frames.filter { $0.profileDeviationDegrees != nil }
        let deviations = estimates.compactMap(\.profileDeviationDegrees)
        guard deviations.count >= minimumSetEstimates else { return .unavailable }
        let median = median(deviations)
        if fits(median, expected: expected) {
            return .matches(medianDeviation: median, estimates: deviations.count)
        }
        let span = (estimates.last?.time ?? 0) - (estimates.first?.time ?? 0)
        if median >= clearlyFrontDegrees && span >= minimumFrontDuration {
            return .mismatch(medianDeviation: median, estimates: deviations.count)
        }
        return .angled(medianDeviation: median, estimates: deviations.count)
    }

    /// True when the latest estimates agree the person is not in the expected view.
    static func previewAsksToTurn(_ recentDeviations: [Double], expected: ExpectedView) -> Bool {
        guard recentDeviations.count >= minimumPreviewEstimates else { return false }
        return !fits(median(recentDeviations), expected: expected)
    }

    private static func fits(_ deviation: Double, expected: ExpectedView) -> Bool {
        switch expected {
        case .side: deviation <= maximumSideDeviationDegrees
        case .any: true
        }
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
