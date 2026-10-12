import AVFoundation
import Foundation

/// Mac-only harness: frame extraction and scoring use the same pose and exercise analyzers as the app.
@main
enum ReplayVideo {
    struct Report: Encodable {
        let exercise: String
        let frameCount: Int
        let measuredReps: Int
        let status: String
        let reason: String?
        let rubricVersion: String?
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
        let report: Report
        switch result {
        case .analyzed(let analysis):
            if analysis.reps.isEmpty {
                let reason = [definition.copy.noCompleteReps,
                              diagnostics?.explanation(for: definition, counted: 0)]
                    .compactMap { $0 }.joined(separator: " ")
                report = Report(exercise: kind.rawValue, frameCount: poses.count,
                                measuredReps: 0, status: "retake", reason: reason,
                                rubricVersion: analysis.rubricVersion)
            } else {
                report = Report(exercise: kind.rawValue, frameCount: poses.count,
                                measuredReps: analysis.reps.count, status: "measured", reason: nil,
                                rubricVersion: analysis.rubricVersion)
            }
        case .insufficientView(let reason):
            report = Report(exercise: kind.rawValue, frameCount: poses.count,
                            measuredReps: 0, status: "retake", reason: reason,
                            rubricVersion: nil)
        case .failed(let reason):
            report = Report(exercise: kind.rawValue, frameCount: poses.count,
                            measuredReps: 0, status: "failed", reason: reason,
                            rubricVersion: nil)
        }
        FileHandle.standardOutput.write(try encoder.encode(report))
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func extract(from url: URL) async throws -> [PoseFrame] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw Failure.noVideoTrack
        }
        let composition = try await AVVideoComposition.videoComposition(withPropertiesOf: asset)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: [track],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        output.videoComposition = composition
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
                  let image = CMSampleBufferGetImageBuffer(sample) else { continue }
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
