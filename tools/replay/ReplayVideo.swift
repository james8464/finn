import AVFoundation
import CoreImage
import Foundation

/// Mac-only harness: frame extraction and scoring use the same pose and exercise analysers as the app.
@main
enum ReplayVideo {
    struct Report: Encodable {
        let exercise: String
        let frameCount: Int
        let measuredReps: Int
        let status: String
        let reason: String?
        let rubricVersion: String?
        /// Reps the hands-free live count reached, feeding the frames one by one as the camera does.
        let liveReps: Int
        /// The highest number the live count showed at any moment: above `liveReps`, the person saw
        /// a count come down during the set.
        var liveMaxReps = 0
        /// Live cues other than the count, as they would be spoken.
        let liveCues: [String]
        /// When the live monitor would have ended the set by itself, if it did.
        let liveStopAt: Double?
        /// When a hands-free start would have triggered (the person held still in position).
        let handsFreeReadyAt: Double?
        /// What the app's angle rules say the exercise is, whatever the person chose.
        var recognized: String?
        /// Start and end of each measured rep, in seconds, to check a count against the video.
        var repTimes: [[Double]] = []
    }

    /// The hands-free path on the same frames: the start readiness, the live count and cues, and
    /// the automatic stop, as `WorkoutSessionModel` drives them during a capture.
    private static func followLive(_ poses: [PoseFrame], definition: ExerciseDefinition)
        -> (reps: Int, maxReps: Int, cues: [String], stopAt: Double?, readyAt: Double?) {
        var maxReps = 0
        var readiness = StartReadiness()
        var monitor = LiveSetMonitor(definition: definition)
        var seen: [PoseFrame] = []
        seen.reserveCapacity(poses.count)
        var cues: [String] = []
        var stopAt: Double?
        var readyAt: Double?
        for frame in poses {
            if readyAt == nil {
                _ = readiness.update(with: frame, definition: definition)
                if readiness.isReady { readyAt = frame.time }
            }
            seen.append(frame)
            for event in monitor.update(with: seen) {
                switch event {
                case .repCounted(let count), .repCountRevised(let count): maxReps = max(maxReps, count)
                default: cues.append(event.spoken(for: definition))
                }
            }
            if stopAt == nil, monitor.isOver { stopAt = frame.time }
        }
        return (monitor.countedReps, maxReps, cues, stopAt, readyAt)
    }

    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("Replay failed: \(error)\n".utf8))
            exit(2)
        }
    }

    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count >= 4, arguments[0] == "--exercise",
              let kind = ExerciseKind(rawValue: arguments[1]),
              ["--video", "--poses"].contains(arguments[2]) else {
            throw Failure.usage
        }
        let input = URL(fileURLWithPath: arguments[3])
        guard FileManager.default.isReadableFile(atPath: input.path) else {
            throw Failure.unreadable(input.path)
        }
        let output: URL?
        if arguments.count == 6, arguments[4] == "--poses-output" {
            output = URL(fileURLWithPath: arguments[5])
        } else if arguments.count == 4 {
            output = nil
        } else {
            throw Failure.usage
        }
        let poses: [PoseFrame]
        if arguments[2] == "--video" {
            poses = try await extract(from: input)
        } else {
            poses = try JSONDecoder().decode([PoseFrame].self, from: Data(contentsOf: input))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let output {
            try encoder.encode(poses).write(to: output, options: .atomic)
        }
        let definition = ExerciseDefinition.definition(for: kind)
        let (result, diagnostics) = ExerciseAnalyzer.analyzeWithDiagnostics(poses, as: definition)
        let live = followLive(poses, definition: definition)
        let report: Report
        switch result {
        case .analyzed(let analysis):
            if analysis.reps.isEmpty {
                let reason = [definition.copy.noCompleteReps,
                              diagnostics?.explanation(for: definition, counted: 0)]
                    .compactMap { $0 }.joined(separator: " ")
                report = Report(exercise: kind.rawValue, frameCount: poses.count,
                                measuredReps: 0, status: "retake", reason: reason,
                                rubricVersion: analysis.rubricVersion,
                                liveReps: live.reps, liveCues: live.cues, liveStopAt: live.stopAt,
                                handsFreeReadyAt: live.readyAt)
            } else {
                report = Report(exercise: kind.rawValue, frameCount: poses.count,
                                measuredReps: analysis.reps.count, status: "measured", reason: nil,
                                rubricVersion: analysis.rubricVersion,
                                liveReps: live.reps, liveCues: live.cues, liveStopAt: live.stopAt,
                                handsFreeReadyAt: live.readyAt)
            }
        case .insufficientView(let reason):
            report = Report(exercise: kind.rawValue, frameCount: poses.count,
                            measuredReps: 0, status: "retake", reason: reason,
                            rubricVersion: nil,
                            liveReps: live.reps, liveCues: live.cues, liveStopAt: live.stopAt,
                            handsFreeReadyAt: live.readyAt)
        case .failed(let reason):
            report = Report(exercise: kind.rawValue, frameCount: poses.count,
                            measuredReps: 0, status: "failed", reason: reason,
                            rubricVersion: nil,
                            liveReps: live.reps, liveCues: live.cues, liveStopAt: live.stopAt,
                            handsFreeReadyAt: live.readyAt)
        }
        var finalReport = report
        finalReport.liveMaxReps = live.maxReps
        if case .analyzed(let analysis) = result, finalReport.status == "measured" {
            finalReport.repTimes = analysis.reps.map { [($0.startTime * 10).rounded() / 10, ($0.endTime * 10).rounded() / 10] }
        }
        switch AngleRecognizer.recognize(poses, using: AngleRuleClassifier()) {
        case .recognized(let kind, _): finalReport.recognized = kind.rawValue
        case .uncertain: finalReport.recognized = "uncertain"
        case .notAttempted: finalReport.recognized = nil
        }
        FileHandle.standardOutput.write(try encoder.encode(finalReport))
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    /// The orientation a track's transform asks for, read from its rotation part only. Videos that a
    /// messaging app re-encoded carry a translation left over from the original size (a 1024 x 576
    /// clip with ty = 3840), and `AVVideoComposition(withPropertiesOf:)` then renders a 576 x 3840
    /// canvas where the person falls mostly off the edge.
    static func orientation(of transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a.rounded(), transform.b.rounded(), transform.c.rounded(), transform.d.rounded()) {
        case (0, 1, -1, 0): .right
        case (0, -1, 1, 0): .left
        case (-1, 0, 0, -1): .down
        case (-1, 0, 0, 1): .upMirrored
        case (1, 0, 0, -1): .downMirrored
        default: .up
        }
    }

    /// Draws `source` upright into a new BGRA buffer.
    private static func upright(_ source: CVPixelBuffer, _ orientation: CGImagePropertyOrientation,
                                context: CIContext, margin: Double = 0) -> CVPixelBuffer? {
        if orientation == .up && margin == 0 { return source }
        let image = CIImage(cvPixelBuffer: source).oriented(orientation)
        let extent = image.extent.integral
// a black border around the picture lets Vision see a person the frame cuts off.
        let border = (extent.width * margin).rounded()
        let width = Int(extent.width + 2 * border)
        let height = Int(extent.height + 2 * border)
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA,
                                  [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
                                  &buffer) == kCVReturnSuccess, let buffer else { return nil }
        let placed = image.transformed(by: CGAffineTransform(translationX: border - extent.minX,
                                                              y: border - extent.minY))
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.render(placed.composited(over: CIImage(color: .black).cropped(to: canvas)), to: buffer)
        return buffer
    }

    private static func extract(from url: URL) async throws -> [PoseFrame] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw Failure.noVideoTrack
        }
        let orientation = orientation(of: try await track.load(.preferredTransform))
        let margin = Double(ProcessInfo.processInfo.environment["FINN_REPLAY_MARGIN"] ?? "") ?? 0
        let context = CIContext()
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        guard reader.canAdd(output) else { throw Failure.reader }
        reader.add(output)
        guard reader.startReading() else { throw Failure.reader }
        let analyzer = PoseFrameAnalyzer()
        analyzer.lockAthlete()
        var poses: [PoseFrame] = []
        var lastSampled = -Double.infinity
        while let sample = output.copyNextSampleBuffer() {
            let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            guard time.isFinite, time - lastSampled >= PoseFrameAnalyzer.minimumInterval,
                  let raw = CMSampleBufferGetImageBuffer(sample),
                  let image = upright(raw, orientation, context: context, margin: margin) else { continue }
            lastSampled = time
            poses.append(analyzer.analyze(image, time: time, estimateAngle: true))
        }
        guard reader.status == .completed else { throw Failure.reader }
        return poses
    }

    enum Failure: Error, CustomStringConvertible {
        case usage, unreadable(String), noVideoTrack, reader

        var description: String {
            switch self {
            case .usage:
                "Usage: replay --exercise bodyweightSquat|pushUp|staticLunge|stiffLegDeadlift --video FILE [--poses-output FILE] (or --poses FILE)"
            case .unreadable(let path): "Cannot read \(path)"
            case .noVideoTrack: "No video track"
            case .reader: "Could not read video frames"
            }
        }
    }
}
