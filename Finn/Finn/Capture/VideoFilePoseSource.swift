#if DEBUG
import AVFoundation

/// debug-only input that plays a video file through the camera's Vision analysis, so the camera
/// screen, the live skeleton, and rep counting can be checked without filming. Launch with
/// `-finn-video-file <path>`. The file is read in place; nothing is copied into the app.
///
/// Vision's body-pose requests do not run on the iOS 27 simulator ("Could not create inference
/// context"). There, add `-finn-video-poses <json>`: poses recorded from the same file on a Mac
/// with `PoseFrameAnalyzer`, replayed in step with the picture
///
/// While framing, the video loops. A set replays it once from the first frame.
@MainActor
final class VideoFilePoseSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    let previewFeed: PreviewFeed?
    private let url: URL
    private let recordedPoses: [PoseFrame]?
    private var continuation: AsyncStream<PoseFrame>.Continuation?
    private var playback: Task<Void, Never>?

    init(url: URL, recordedPoses: [PoseFrame]? = nil) {
        self.url = url
        self.recordedPoses = recordedPoses
        previewFeed = PreviewFeed(isMirrored: false, device: nil)
    }

    func start() async throws -> AsyncStream<PoseFrame> {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw CameraSourceError.unavailable
        }
        // keep the finite fixture intact if a simulator pauses the UI test while taking screenshots
        let stream = AsyncStream(PoseFrame.self, bufferingPolicy: .bufferingNewest(256)) { continuation in
            self.continuation = continuation
        }
        play(looping: true)
        return stream
    }

    func prepareForSet() async {
        play(looping: false)
    }

    func stop() async {
        playback?.cancel()
        playback = nil
        continuation?.finish()
        continuation = nil
    }

    private func play(looping: Bool) {
        playback?.cancel()
        guard let continuation, let sink = previewFeed?.sink else { return }
        let url = url
        let recordedPoses = recordedPoses
        playback = Task.detached(priority: .userInitiated) {
            await VideoFileReader.play(url: url, sink: sink, looping: looping,
                                       recordedPoses: recordedPoses) { frame in
                continuation.yield(frame)
            }
        }
    }
}

nonisolated enum VideoFileReader {
    /// reads the file upright (its rotation applied), shows every frame at its own pace, and
    /// analyses 15 frames per second, like the camera
    static func play(url: URL, sink: PreviewFrameSink, looping: Bool, recordedPoses: [PoseFrame]? = nil,
                     yield: @Sendable (PoseFrame) -> Void) async {
        let asset = AVURLAsset(url: url)
        let analyzer = PoseFrameAnalyzer()
        // a set (played once) follows the person picked on its first frame throughout
        if !looping { analyzer.lockAthlete() }
        repeat {
            guard let track = try? await asset.loadTracks(withMediaType: .video).first,
                  let composition = try? await AVVideoComposition.videoComposition(withPropertiesOf: asset),
                  let reader = try? AVAssetReader(asset: asset) else { return }
            let output = AVAssetReaderVideoCompositionOutput(
                videoTracks: [track],
                videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            output.videoComposition = composition
            guard reader.canAdd(output) else { return }
            let provider = reader.outputProvider(for: output)
            guard (try? reader.start()) != nil else { return }
            let clock = ContinuousClock()
            // Start the replay clock after the decoder delivers its first frame.
            // Simulator decoder startup can otherwise compress the whole movement into a burst.
            var start: ContinuousClock.Instant?
            var lastAnalyzed = -Double.infinity
            while !Task.isCancelled, let ready = try? await provider.next() {
                let sample = ready.withUnsafeSampleBuffer { $0 }
                let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
                guard time.isFinite else { continue }
                if start == nil { start = clock.now }
                if let start {
                    try? await clock.sleep(until: start + .milliseconds(Int(time * 1000)))
                }
                guard !Task.isCancelled else { break }
                sink.enqueue(sample)
                if time - lastAnalyzed >= PoseFrameAnalyzer.minimumInterval,
                   let pixelBuffer = CMSampleBufferGetImageBuffer(sample) {
                    lastAnalyzed = time
                    let frame: PoseFrame
                    if let recordedPoses {
                        guard let recorded = nearest(recordedPoses, to: time) else { continue }
                        frame = recorded.retimed(to: time)
                    } else {
                        frame = analyzer.analyze(pixelBuffer, time: time, estimateAngle: true)
                    }
                    guard !Task.isCancelled else { break }
                    yield(frame)
                }
            }
            reader.cancelReading()
        } while looping && !Task.isCancelled
    }

    /// the recorded pose closest in time, if one is within a frame of it
    static func nearest(_ poses: [PoseFrame], to time: TimeInterval) -> PoseFrame? {
        var low = 0
        var high = poses.count
        while low < high {
            let middle = (low + high) / 2
            if poses[middle].time < time { low = middle + 1 } else { high = middle }
        }
        let candidates = [low - 1, low].filter { poses.indices.contains($0) }.map { poses[$0] }
        guard let best = candidates.min(by: { abs($0.time - time) < abs($1.time - time) }),
              abs(best.time - time) <= 0.05 else { return nil }
        return best
    }
}
#endif
