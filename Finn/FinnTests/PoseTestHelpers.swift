@testable import Finn

/// Adds a 3D profile deviation at the camera's usual sampling interval.
func withDeviation(_ frames: [PoseFrame], _ degrees: Double, every: Int = 4) -> [PoseFrame] {
    frames.enumerated().map { index, frame in
        PoseFrame(
            time: frame.time,
            subjectCount: frame.subjectCount,
            joints: frame.joints,
            aspectRatio: frame.aspectRatio,
            keypoints: frame.keypoints,
            profileDeviationDegrees: index.isMultiple(of: every) ? degrees : nil,
            athleteTracking: frame.athleteTracking,
            bystanders: frame.bystanders
        )
    }
}
