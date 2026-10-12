import CoreML
import CoreVideo
import Vision

/// Runs Vision on one upright, unmirrored frame and returns the pose record Plumb keeps: the
/// athlete's joints, picked and followed by `AthleteTracker`, and everyone else as bystanders.
/// The camera and the Debug video-file source share it, so both analyze frames the same way.
/// Not thread-safe: call it from one queue.
nonisolated final class PoseFrameAnalyzer {
    /// Frames are analyzed 15 times per second. The millisecond of slack keeps every other frame
    /// of a 30 fps stream: their timestamps differ by a hair less than 1/15 s.
    static let minimumInterval = 1.0 / 15 - 0.001
    /// Runs every Nth analyzed frame (about 4 per second at 15 fps) to bound the extra cost.
    static let cameraAngleInterval = 4
    /// Pose confidence can remain high when Vision guesses a hidden joint. Check the person
    /// silhouette on every third analyzed frame; missing evidence then fails the 80% view gate.
    static let silhouetteInterval = 3
    // The 3D request is stateful, so it is reused across frames.
    private let poseRequest3D = VNDetectHumanBodyPose3DRequest()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var analyzedFrames = 0
    private var tracker = AthleteTracker()
    private var lastMaskSupportedJoints: Set<BodyJoint>?

    /// Keep following the current athlete until `releaseAthlete()`; called when a set starts.
    func lockAthlete() { tracker.lock() }

    /// Pick the most prominent person again on the next frame.
    func releaseAthlete() {
        tracker.reset()
        lastMaskSupportedJoints = nil
    }

    func analyze(_ pixelBuffer: CVPixelBuffer, time: TimeInterval, estimateAngle: Bool) -> PoseFrame {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let aspectRatio = width > 0 && height > 0 ? Double(height) / Double(width) : 1
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        analyzedFrames += 1
        let verifySilhouette = analyzedFrames % Self.silhouetteInterval == 0
        // Use a fresh request for each sample. Reusing one lagged behind the next pose in video
        // replay, causing clear joints to be rejected after a movement transition.
        let maskRequest: VNGeneratePersonSegmentationRequest? = verifySilhouette
            ? VNGeneratePersonSegmentationRequest() : nil
        maskRequest?.qualityLevel = .fast
        maskRequest?.outputPixelFormat = kCVPixelFormatType_OneComponent8
        do {
            let requests: [VNRequest] = maskRequest.map { [request, $0] } ?? [request]
            try handler.perform(requests)
        } catch {
            return PoseFrame(time: time, subjectCount: 0, joints: [:], aspectRatio: aspectRatio,
                             athleteTracking: .hidden)
        }

        let observations = request.results ?? []
        let people = observations.map(Self.joints(of:))
        let athlete = tracker.select(people, aspectRatio: aspectRatio, time: time)
        var joints: [BodyJoint: JointPoint] = [:]
        var keypoints: [Float]?
        if let athlete {
            // The same 18-point layout Create ML extracts from training clips.
            if let array = try? observations[athlete].keypointsMultiArray() {
                let values = MLShapedArray<Float>(converting: array).scalars
                keypoints = values.count == ExerciseRecognizer.keypointCount ? values : nil
            }
            joints = people[athlete]
            if verifySilhouette {
                // On a mask failure, leave no measured joints in this sample. Repeated failures
                // make the evidence gate ask for a retake rather than trusting inferred joints.
                joints = Self.corroborated(joints, by: maskRequest?.results?.first?.pixelBuffer)
                lastMaskSupportedJoints = Set(joints.keys)
            } else if let lastMaskSupportedJoints {
                // Carry a negative mask verdict through the two frames between checks. Otherwise
                // framing can alternate between "visible" and "move the phone" over covered feet.
                joints = joints.filter { lastMaskSupportedJoints.contains($0.key) }
            }
        } else if verifySilhouette {
            lastMaskSupportedJoints = []
        }
        var profileDeviation: Double?
        if estimateAngle, athlete != nil, analyzedFrames % Self.cameraAngleInterval == 0 {
            profileDeviation = cameraAngle(in: pixelBuffer, athlete: joints)
        }
        let bystanders = people.indices.filter { $0 != athlete }.map { people[$0] }.filter { !$0.isEmpty }
        return PoseFrame(time: time, subjectCount: observations.count, joints: joints,
                         aspectRatio: aspectRatio, keypoints: keypoints,
                         profileDeviationDegrees: profileDeviation,
                         athleteTracking: athlete == nil ? .hidden : .tracked,
                         bystanders: bystanders)
    }

    /// Keep a joint only when the person mask includes pixels at or immediately around it.
    /// Vision's 2D skeleton is allowed to estimate through an obstruction; the mask supplies
    /// independent image evidence. The small neighborhood tolerates pose/mask edge alignment.
    /// This mask covers all people; AthleteTracker still owns identity and overlap needs testing.
    private static func corroborated(_ joints: [BodyJoint: JointPoint],
                                     by mask: CVPixelBuffer?) -> [BodyJoint: JointPoint] {
        guard let mask, CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else {
            return [:]
        }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self) else {
            return [:]
        }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        guard width > 0, height > 0 else { return [:] }
        return joints.filter { _, point in
            let x = min(width - 1, max(0, Int(point.x * Double(width))))
            let y = min(height - 1, max(0, Int(point.y * Double(height))))
            for dy in -2...2 {
                for dx in -2...2 {
                    let xx = min(width - 1, max(0, x + dx))
                    let yy = min(height - 1, max(0, y + dy))
                    if base[yy * stride + xx] >= 128 { return true }
                }
            }
            return false
        }
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

    /// Profile deviation from Vision 3D pose, or nil when the request fails, the hips are not
    /// estimated, or the 3D body Vision chose is not the athlete (its root falls outside the
    /// athlete's 2D joints). Vision gives each joint relative to the body's root, in the body's
    /// own axes, and `cameraOriginMatrix` takes those into the camera's frame.
    /// `cameraRelativePosition` only shifts them by the root's position without turning them, so
    /// the body always looked square to the camera: every set read as filmed from the front
    /// (74 to 89° on 50 side-view videos).
    private func cameraAngle(in pixelBuffer: CVPixelBuffer, athlete: [BodyJoint: JointPoint]) -> Double? {
        guard (try? sequenceHandler.perform([poseRequest3D], on: pixelBuffer, orientation: .up)) != nil,
              let body = poseRequest3D.results?.first,
              let root = try? body.pointInImage(.root) else { return nil }
        let xs = athlete.values.map(\.x)
        let ys = athlete.values.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        let margin = 0.1 * max(maxX - minX, maxY - minY)
        let rootX = Double(root.location.x)
        let rootY = 1 - Double(root.location.y)
        guard (minX - margin...maxX + margin).contains(rootX),
              (minY - margin...maxY + margin).contains(rootY) else { return nil }
        let toCamera = body.cameraOriginMatrix
        func position(_ joint: VNHumanBodyPose3DObservation.JointName) -> SIMD3<Double>? {
            guard let local = try? body.recognizedPoint(joint).position.columns.3 else { return nil }
            let camera = toCamera * SIMD4<Float>(local.x, local.y, local.z, 1)
            return SIMD3(Double(camera.x), Double(camera.y), Double(camera.z))
        }
        guard let leftHip = position(.leftHip), let rightHip = position(.rightHip) else { return nil }
        return ViewCheck.profileDeviation(leftHip: leftHip, rightHip: rightHip,
                                          leftShoulder: position(.leftShoulder),
                                          rightShoulder: position(.rightShoulder))
    }
}
