import AVFoundation

nonisolated enum CameraCaptureError: Error {
    case noFrontCamera
    case cannotConfigure
    case cannotStart
}

nonisolated final class AVCameraCaptureDriver: NSObject, CameraCaptureDriving, @unchecked Sendable {
    nonisolated(unsafe) let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.plumb.camera.capture")
    private let processor: PoseFrameProcessor
    private var configured = false
    private var interruptionObserver: NSObjectProtocol?
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
        return stream
    }

    func setCameraAngleEstimation(_ enabled: Bool) {
        processor.setCameraAngleEstimation(enabled)
    }

    func lockAthlete() {
        processor.requestAthlete(locked: true)
    }

    /// Turns the frames so the person stands upright in them, whatever the phone's orientation.
    func setCaptureRotation(_ degrees: Double) {
        queue.async {
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if self.session.isRunning { self.session.stopRunning() }
                continuation.resume()
            }
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
            // Portrait until the screen's rotation coordinator reports the phone's orientation.
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
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
    private var athleteRequest: Bool?
    private let previewSink: PreviewFrameSink?
    // Used only on the capture queue.
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

    /// Lock onto the current athlete (a set starts) or pick again (a new preview), applied on
    /// the capture queue before the next analyzed frame.
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
        // Every frame goes on screen; the analysis keeps 15 per second.
        let analyze = time - lastSampleTime >= PoseFrameAnalyzer.minimumInterval
        if analyze { lastSampleTime = time }
        let estimateAngle = estimatesCameraAngle
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
