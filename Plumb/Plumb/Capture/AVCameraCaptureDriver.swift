import AVFoundation
import ImageIO
import Vision

nonisolated enum CameraCaptureError: Error {
    case noFrontCamera
    case cannotConfigure
    case cannotStart
}

nonisolated final class AVCameraCaptureDriver: NSObject, CameraCaptureDriving, @unchecked Sendable {
    nonisolated(unsafe) let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.plumb.camera.capture")
    private let processor = PoseFrameProcessor()
    private var configured = false
    private var interruptionObserver: NSObjectProtocol?

    var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

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
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        else { throw CameraCaptureError.noFrontCamera }

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
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
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

    func makeStream() -> AsyncStream<PoseFrame> {
        lock.lock()
        defer { lock.unlock() }
        lastSampleTime = -.infinity
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
        guard continuation != nil, time - lastSampleTime >= 1.0 / 15 else {
            lock.unlock()
            return
        }
        lastSampleTime = time
        lock.unlock()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let aspectRatio = width > 0 && height > 0 ? Double(height) / Double(width) : 1
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            yield(PoseFrame(time: time, subjectCount: 0, joints: [:], aspectRatio: aspectRatio))
            return
        }

        let observations = request.results ?? []
        let subject = observations.first
        var joints: [BodyJoint: JointPoint] = [:]
        if let subject {
            let mapping: [(BodyJoint, VNHumanBodyPoseObservation.JointName)] = [
                (.leftHip, .leftHip), (.leftKnee, .leftKnee), (.leftAnkle, .leftAnkle),
                (.rightHip, .rightHip), (.rightKnee, .rightKnee), (.rightAnkle, .rightAnkle),
                (.leftShoulder, .leftShoulder), (.leftElbow, .leftElbow), (.leftWrist, .leftWrist),
                (.rightShoulder, .rightShoulder), (.rightElbow, .rightElbow), (.rightWrist, .rightWrist),
            ]
            for (name, visionName) in mapping {
                guard let point = try? subject.recognizedPoint(visionName), point.confidence > 0 else { continue }
                joints[name] = JointPoint(
                    x: min(1, max(0, Double(point.location.x))),
                    y: min(1, max(0, 1 - Double(point.location.y))),
                    confidence: Double(point.confidence)
                )
            }
        }
        yield(PoseFrame(time: time, subjectCount: observations.count, joints: joints,
                        aspectRatio: aspectRatio))
    }

    private func yield(_ frame: PoseFrame) {
        lock.lock()
        let active = continuation
        lock.unlock()
        active?.yield(frame)
    }
}
