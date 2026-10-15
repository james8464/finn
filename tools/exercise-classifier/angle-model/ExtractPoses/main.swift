// extracts Vision 2D body poses from videos, the way the app does on the iPhone, and writes one
// JSON file of PoseFrame values per video. Videos are only decoded, never executed or uploaded.
//
//   extract-poses <videos folder> <output folder>
//
// Folder layout: <exercise>/<quality>/<file>.mp4 (the Mendeley side-view layout). Built by
// build.sh together with Finn/Finn/Workout/WorkoutModels.swift.

import AVFoundation
import Foundation
import Vision

struct PoseRecording: Codable {
    let source: String
    let exercise: String
    let label: String
    let subject: String
    let frames: [PoseFrame]
}

/// Folder exercise name to classifier label: the two exercises Finn supports keep their label,
/// every other exercise in the dataset is "other".
func label(forExercise exercise: String) -> String {
    switch exercise {
    case "squat": "squat"
    case "push_up": "push_up"
    default: "other"
    }
}

func orientation(of transform: CGAffineTransform) -> CGImagePropertyOrientation {
    switch Int((atan2(transform.b, transform.a) * 180 / .pi).rounded()) {
    case 90: .right
    case -90: .left
    case 180, -180: .down
    default: .up
    }
}

let mapping: [(BodyJoint, VNHumanBodyPoseObservation.JointName)] = [
    (.leftHip, .leftHip), (.leftKnee, .leftKnee), (.leftAnkle, .leftAnkle),
    (.rightHip, .rightHip), (.rightKnee, .rightKnee), (.rightAnkle, .rightAnkle),
    (.leftShoulder, .leftShoulder), (.leftElbow, .leftElbow), (.leftWrist, .leftWrist),
    (.rightShoulder, .rightShoulder), (.rightElbow, .rightElbow), (.rightWrist, .rightWrist),
]

/// Diagonal of the box around a person's confidently detected joints, so a person lying down
/// for push-ups counts as much as a person standing. `aspectRatio` is image height over width.
func extent(of observation: VNHumanBodyPoseObservation, aspectRatio: Double) -> Double {
    let points = ((try? observation.recognizedPoints(.all)) ?? [:]).values.filter { $0.confidence > 0.1 }
    guard let minX = points.map(\.location.x).min(), let maxX = points.map(\.location.x).max(),
          let minY = points.map(\.location.y).min(), let maxY = points.map(\.location.y).max() else { return 0 }
    return hypot(Double(maxX - minX), Double(maxY - minY) * aspectRatio)
}

func extract(_ url: URL) async throws -> [PoseFrame] {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else { return [] }
    let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
    let imageOrientation = orientation(of: transform)
    let rotated = imageOrientation == .left || imageOrientation == .right
    let aspectRatio = rotated ? Double(size.width / size.height) : Double(size.height / size.width)

    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
    ])
    reader.add(output)
    reader.startReading()

    var frames: [PoseFrame] = []
    var lastTime = -Double.infinity
    var firstTime: Double?
    while let sample = output.copyNextSampleBuffer() {
        let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
        guard time.isFinite, time - lastTime >= 1.0 / 15 - 1e-3,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
        lastTime = time
        let start = firstTime ?? time
        firstTime = start
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: imageOrientation)
        try? handler.perform([request])
        let observations = request.results ?? []
        var joints: [BodyJoint: JointPoint] = [:]
// gyms have bystanders: keep the person who fills most of the frame, the one exercising.
        if let subject = observations.max(by: {
            extent(of: $0, aspectRatio: aspectRatio) < extent(of: $1, aspectRatio: aspectRatio)
        }) {
            for (name, visionName) in mapping {
                guard let point = try? subject.recognizedPoint(visionName), point.confidence > 0 else { continue }
                joints[name] = JointPoint(x: min(1, max(0, Double(point.location.x))),
                                          y: min(1, max(0, 1 - Double(point.location.y))),
                                          confidence: Double(point.confidence))
            }
        }
        frames.append(PoseFrame(time: time - start, subjectCount: observations.count, joints: joints,
                                aspectRatio: aspectRatio))
    }
    if reader.status == .failed { throw reader.error ?? CocoaError(.fileReadCorruptFile) }
    return frames
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: extract-poses <videos folder> <output folder>")
    exit(2)
}
let input = URL(fileURLWithPath: arguments[1]), outputFolder = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
let videos = (FileManager.default.enumerator(at: input, includingPropertiesForKeys: nil)?
    .compactMap { $0 as? URL } ?? []).filter { $0.pathExtension.lowercased() == "mp4" }.sorted { $0.path < $1.path }
print("\(videos.count) videos")
let encoder = JSONEncoder()
var written = 0
for video in videos {
    let relative = String(video.path.dropFirst(input.path.count + 1))
    let parts = relative.split(separator: "/")
    let exercise = parts.first.map(String.init) ?? "unknown"
    let subject = video.lastPathComponent.split(separator: "_").prefix(2).joined(separator: "_")
    let target = outputFolder.appending(path: relative.replacingOccurrences(of: "/", with: "__") + ".json")
    if FileManager.default.fileExists(atPath: target.path) { written += 1; continue }
    do {
        let frames = try await extract(video)
        let recording = PoseRecording(source: relative, exercise: exercise, label: label(forExercise: exercise),
                                      subject: subject, frames: frames)
        try encoder.encode(recording).write(to: target, options: .atomic)
        written += 1
        if written % 20 == 0 { print("\(written) of \(videos.count)") }
    } catch {
        print("skipped \(relative): \(error)")
    }
}
print("done \(written) of \(videos.count)")
