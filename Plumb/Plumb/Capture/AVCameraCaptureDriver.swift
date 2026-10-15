import AVFoundation

nonisolated enum CameraCaptureError: Error {
    case noFrontCamera
    case cannotConfigure
    case cannotStart
}

nonisolated final class AVCameraCaptureDriver: NSObject, CameraCaptureDriving, @unchecked Sendable {
    nonisolated(unsafe) let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "ai.mwm.build.challenge.team.08.camera.capture")
    private let processor: PoseFrameProcessor
    private var configured = false
    private var interruptionObserver: NSObjectProtocol?
    private var runtimeErrorObserver: NSObjectProtocol?
    private var pressureObservation: NSKeyValueObservation?
    /// the rotation that makes frames upright; used when the session is configured. Capture queue only
    private var captureRotation = 90.0
    /// capture runs at 15 frames per second because of system pressure. Capture queue only
    private var lowersFrameRate = false
    nonisolated let previewSink: PreviewFrameSink? = PreviewFrameSink()
    nonisolated let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

    override init() {
        processor = PoseFrameProcessor(previewSink: previewSink)
        super.init()
    }

    var isAvailable: Bool { cameraDevice != nil }

    func start() async throws -> AsyncStream<PoseFrame> {
        let stream = processor.makeStream()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                queue.async {
                    do {
                        if !self.configured { try self.configure() }
                        self.session.startRunning()
                        guard self.session.isRunning else { throw CameraCaptureError.cannotStart }
                        continuation.resume()
                    } catch {
                        self.processor.finish()
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            processor.finish()
            throw error
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: nil
        ) { [processor] _ in
            processor.finish()
        }
        // a media-services reset or another runtime error stops the frames: end the stream so the
        // screen says the camera stopped instead of freezing.
        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: nil
        ) { [processor] _ in
            processor.finish()
        }
        // a hot phone: lighten the work before the system has to stop the camera mid-set.
        // .initial applies the current level on every start: a set may begin hot, or after cooling.
        pressureObservation = cameraDevice?.observe(\.systemPressureState, options: [.initial, .new]) {
            [weak self] device, _ in
            self?.adapt(to: device.systemPressureState.level)
        }
        return stream
    }

    func setCameraAngleEstimation(_ enabled: Bool) {
        processor.setCameraAngleEstimation(enabled)
    }

    func lockAthlete() {
        processor.requestAthlete(locked: true)
    }

    /// turns the frames so the person stands upright in them, whatever the phone's orientation.
    /// Before the session starts, the angle is kept for its first frames.
    func setCaptureRotation(_ degrees: Double) {
        queue.async {
            self.captureRotation = degrees
            guard let connection = self.session.outputs.first?.connection(with: .video),
                  connection.isVideoRotationAngleSupported(degrees),
                  connection.videoRotationAngle != degrees else { return }
            connection.videoRotationAngle = degrees
        }
    }

    func stop() async {
        processor.finish()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        if let runtimeErrorObserver {
            NotificationCenter.default.removeObserver(runtimeErrorObserver)
            self.runtimeErrorObserver = nil
        }
        pressureObservation?.invalidate()
        pressureObservation = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if self.session.isRunning { self.session.stopRunning() }
                continuation.resume()
            }
        }
    }

    /// under serious system pressure (heat), capture at the analysis rate (15 frames per second)
    /// and skip the optional 3D angle estimate; back to normal once the pressure drops.
    private func adapt(to level: AVCaptureDevice.SystemPressureState.Level) {
        let strained = level == .serious || level == .critical
        processor.setUnderPressure(strained)
        queue.async {
            guard strained != self.lowersFrameRate, let camera = self.cameraDevice else { return }
            // only a rate the current format supports; anything else would raise an exception.
            let supportsAnalysisRate = camera.activeFormat.videoSupportedFrameRateRanges.contains {
                $0.minFrameRate <= 15 && $0.maxFrameRate >= 15
            }
            guard supportsAnalysisRate, (try? camera.lockForConfiguration()) != nil else { return }
            camera.activeVideoMinFrameDuration = strained ? CMTime(value: 1, timescale: 15) : .invalid
            camera.unlockForConfiguration()
            self.lowersFrameRate = strained
        }
    }

    private func configure() throws {
        guard let camera = cameraDevice else { throw CameraCaptureError.noFrontCamera }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw CameraCaptureError.cannotConfigure }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        guard session.canAddOutput(output) else { throw CameraCaptureError.cannotConfigure }
        session.addOutput(output)
        output.setSampleBufferDelegate(processor, queue: queue)
        if let connection = output.connection(with: .video) {
            // upright from the first frame: the angle the camera source read from a rotation
            // coordinator (the iPhone 17 front sensor is mounted in portrait, so not always 90°).
            // The camera screen keeps it updated when the phone turns.
            if connection.isVideoRotationAngleSupported(captureRotation) {
                connection.videoRotationAngle = captureRotation
            } else if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            // Vision reads unmirrored frames; only the on-screen picture is mirrored.
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        configured = true
    }
}

nonisolated private final class PoseFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<PoseFrame>.Continuation?
    private var lastSampleTime: Double = -.infinity
    private var estimatesCameraAngle = true
    /// the phone is hot: the 3D angle estimate is skipped until it cools down.
    private var underPressure = false
    private var athleteRequest: Bool?
    private let previewSink: PreviewFrameSink?
    // used only on the capture queue.
    private let analyzer = PoseFrameAnalyzer()

    init(previewSink: PreviewFrameSink?) {
        self.previewSink = previewSink
        super.init()
    }

    func setCameraAngleEstimation(_ enabled: Bool) {
        lock.lock()
        estimatesCameraAngle = enabled
        lock.unlock()
    }

    func setUnderPressure(_ strained: Bool) {
        lock.lock()
        underPressure = strained
        lock.unlock()
    }

    /// lock onto the current athlete (a set starts) or pick again (a new preview), applied on
    /// the capture queue before the next analysed frame.
    func requestAthlete(locked: Bool) {
        lock.lock()
        athleteRequest = locked
        lock.unlock()
    }

    func makeStream() -> AsyncStream<PoseFrame> {
        lock.lock()
        defer { lock.unlock() }
        lastSampleTime = -.infinity
        athleteRequest = false
        return AsyncStream(PoseFrame.self, bufferingPolicy: .bufferingNewest(3)) { continuation in
            self.continuation = continuation
        }
    }

    func finish() {
        lock.lock()
        let active = continuation
        continuation = nil
        lock.unlock()
        active?.finish()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        guard time.isFinite else { return }
        lock.lock()
        guard continuation != nil else {
            lock.unlock()
            return
        }
        // every frame goes on screen; the analysis keeps 15 per second.
        let analyze = time - lastSampleTime >= PoseFrameAnalyzer.minimumInterval
        if analyze { lastSampleTime = time }
        let estimateAngle = estimatesCameraAngle && !underPressure
        let request = analyze ? athleteRequest : nil
        if request != nil { athleteRequest = nil }
        lock.unlock()

        previewSink?.enqueue(sampleBuffer)
        guard analyze, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        switch request {
        case true?: analyzer.lockAthlete()
        case false?: analyzer.releaseAthlete()
        case nil: break
        }
        yield(analyzer.analyze(pixelBuffer, time: time, estimateAngle: estimateAngle))
    }

    private func yield(_ frame: PoseFrame) {
        lock.lock()
        let active = continuation
        lock.unlock()
        active?.yield(frame)
    }
}
