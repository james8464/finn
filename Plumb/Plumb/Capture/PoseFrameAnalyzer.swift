import CoreML
import CoreVideo
import Vision

/// Runs Vision on one upright, unmirrored frame and returns the pose record Plumb keeps.
/// The camera and the Debug video-file source share it, so both analyze frames the same way.
/// Not thread-safe: call it from one queue.
nonisolated final class PoseFrameAnalyzer {
    /// Frames are analyzed 15 times per second. The millisecond of slack keeps every other frame
    /// of a 30 fps stream: their timestamps differ by a hair less than 1/15 s.
    static let minimumInterval = 1.0 / 15 - 0.001
    /// Runs every Nth analyzed frame (about 4 per second at 15 fps) to bound the extra cost.
    static let cameraAngleInterval = 4
    // The 3D request is stateful, so it is reused across frames.
    private let poseRequest3D = VNDetectHumanBodyPose3DRequest()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var analyzedFrames = 0

    func analyze(_ pixelBuffer: CVPixelBuffer, time: TimeInterval, estimateAngle: Bool) -> PoseFrame {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let aspectRatio = width > 0 && height > 0 ? Double(height) / Double(width) : 1
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return PoseFrame(time: time, subjectCount: 0, joints: [:], aspectRatio: aspectRatio)
        }

        let observations = request.results ?? []
        let subject = observations.first
        var joints: [BodyJoint: JointPoint] = [:]
        var keypoints: [Float]?
        if let subject {
            // The same 18-point layout Create ML extracts from training clips.
            if let array = try? subject.keypointsMultiArray() {
                let values = MLShapedArray<Float>(converting: array).scalars
                keypoints = values.count == ExerciseRecognizer.keypointCount ? values : nil
            }
            joints = Self.joints(of: subject)
        }
        analyzedFrames += 1
        var profileDeviation: Double?
        if estimateAngle, subject != nil, analyzedFrames % Self.cameraAngleInterval == 0 {
            profileDeviation = cameraAngle(in: pixelBuffer)
        }
        return PoseFrame(time: time, subjectCount: observations.count, joints: joints,
                         aspectRatio: aspectRatio, keypoints: keypoints,
                         profileDeviationDegrees: profileDeviation)
    }

    /// Vision's points use a bottom-left origin; Plumb's use top-left, like the screen.
    static func joints(of observation: VNHumanBodyPoseObservation) -> [BodyJoint: JointPoint] {
        let mapping: [(BodyJoint, VNHumanBodyPoseObservation.JointName)] = [
            (.leftHip, .leftHip), (.leftKnee, .leftKnee), (.leftAnkle, .leftAnkle),
            (.rightHip, .rightHip), (.rightKnee, .rightKnee), (.rightAnkle, .rightAnkle),
            (.leftShoulder, .leftShoulder), (.leftElbow, .leftElbow), (.leftWrist, .leftWrist),
            (.rightShoulder, .rightShoulder), (.rightElbow, .rightElbow), (.rightWrist, .rightWrist),
        ]
        var joints: [BodyJoint: JointPoint] = [:]
        for (name, visionName) in mapping {
            guard let point = try? observation.recognizedPoint(visionName), point.confidence > 0 else { continue }
            joints[name] = JointPoint(
                x: min(1, max(0, Double(point.location.x))),
                y: min(1, max(0, 1 - Double(point.location.y))),
                confidence: Double(point.confidence)
            )
        }
        return joints
    }

    /// Profile deviation from Vision 3D pose of the most prominent person, or nil when the
    /// request fails or the hips are not estimated.
    private func cameraAngle(in pixelBuffer: CVPixelBuffer) -> Double? {
        guard (try? sequenceHandler.perform([poseRequest3D], on: pixelBuffer, orientation: .up)) != nil,
              let body = poseRequest3D.results?.first else { return nil }
        func position(_ joint: VNHumanBodyPose3DObservation.JointName) -> SIMD3<Double>? {
            guard let matrix = try? body.cameraRelativePosition(joint) else { return nil }
            let column = matrix.columns.3
            return SIMD3(Double(column.x), Double(column.y), Double(column.z))
        }
        guard let leftHip = position(.leftHip), let rightHip = position(.rightHip) else { return nil }
        return ViewCheck.profileDeviation(leftHip: leftHip, rightHip: rightHip,
                                          leftShoulder: position(.leftShoulder),
                                          rightShoulder: position(.rightShoulder))
    }
}
