import AVFoundation

@MainActor
protocol PoseStreaming: AnyObject {
    var previewSession: AVCaptureSession { get }
    /// the frames shown on the camera screen, the same ones the analysis receives
    var previewFeed: PreviewFeed? { get }
    var endedAtLimit: Bool { get }
    func prepareForSet() async
    func start() async throws -> AsyncStream<PoseFrame>
    func stop() async
    /// allows a source to prepare exercise-specific input. Live camera sources ignore this.
    func configure(for exercise: ExerciseKind)
    /// turns Vision 3D camera-angle estimates on or off for the frames that follow
    func setCameraAngleEstimation(_ enabled: Bool)
}

extension PoseStreaming {
    var previewFeed: PreviewFeed? { nil }
    var endedAtLimit: Bool { false }
    func prepareForSet() async {}
    func configure(for exercise: ExerciseKind) {}
    func setCameraAngleEstimation(_ enabled: Bool) {}
}

@MainActor
protocol CameraCaptureDriving: AnyObject {
    var session: AVCaptureSession { get }
    var isAvailable: Bool { get }
    func start() async throws -> AsyncStream<PoseFrame>
    func stop() async
    func setCameraAngleEstimation(_ enabled: Bool)
    /// where every captured frame is sent for display
    var previewSink: PreviewFrameSink? { get }
    var cameraDevice: AVCaptureDevice? { get }
    /// rotates captured frames so the person stands upright in them
    func setCaptureRotation(_ degrees: Double)
    /// keeps the analysis on the person it follows now, for the whole set
    func lockAthlete()
}

extension CameraCaptureDriving {
    func setCameraAngleEstimation(_ enabled: Bool) {}
    var previewSink: PreviewFrameSink? { nil }
    var cameraDevice: AVCaptureDevice? { nil }
    func setCaptureRotation(_ degrees: Double) {}
    func lockAthlete() {}
}

nonisolated enum CameraSourceError: Error, Equatable {
    case denied
    case unavailable
    case alreadyRunning
    case cancelled
}

nonisolated enum CameraSourceState: Equatable {
    case idle
    case starting
    case running
    case interrupted
}

@MainActor
final class CameraPoseSource: PoseStreaming {
    private let authorise: @MainActor () async -> Bool
    private let driver: any CameraCaptureDriving
    private let setDurationLimit: Duration
    private let setDurationLimitSeconds: TimeInterval
    private var runID: UUID?
    private var continuation: AsyncStream<PoseFrame>.Continuation?
    private var forwardTask: Task<Void, Never>?
    private var limitTask: Task<Void, Never>?
    private var isSetActive = false

    private(set) var state: CameraSourceState = .idle
    private(set) var endedAtLimit = false
    var previewSession: AVCaptureSession { driver.session }
    let previewFeed: PreviewFeed?

    init(authorise: @escaping @MainActor () async -> Bool, driver: any CameraCaptureDriving,
         setDurationLimit: Duration = .seconds(120)) {
        self.authorise = authorise
        self.driver = driver
        self.setDurationLimit = setDurationLimit
        let components = setDurationLimit.components
        self.setDurationLimitSeconds = Double(components.seconds)
            + Double(components.attoseconds) / 1e18
        if let sink = driver.previewSink {
            // the front camera is shown like a mirror
            let feed = PreviewFeed(isMirrored: true, device: driver.cameraDevice, sink: sink)
            feed.onCaptureRotation = { [weak driver] degrees in driver?.setCaptureRotation(degrees) }
            previewFeed = feed
        } else {
            previewFeed = nil
        }
    }

    static func live() -> CameraPoseSource {
        CameraPoseSource(authorise: {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return true
            case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
            default: return false
            }
        }, driver: AVCameraCaptureDriver())
    }

    func setCameraAngleEstimation(_ enabled: Bool) {
        driver.setCameraAngleEstimation(enabled)
    }

    func prepareForSet() async {
        guard state == .running, !isSetActive, let currentID = runID else { return }
        isSetActive = true
        driver.lockAthlete()
        limitTask = Task { @MainActor [weak self, setDurationLimit] in
            do { try await Task.sleep(for: setDurationLimit) } catch { return }
            guard let self, self.runID == currentID, self.isSetActive else { return }
            self.endedAtLimit = true
            await self.stop()
        }
    }

    func start() async throws -> AsyncStream<PoseFrame> {
        guard state != .running && state != .starting else { throw CameraSourceError.alreadyRunning }
        let currentID = UUID()
        runID = currentID
        state = .starting
        guard await authorise() else {
            if runID == currentID { runID = nil; state = .idle }
            throw CameraSourceError.denied
        }
        guard runID == currentID else { throw CameraSourceError.cancelled }
        guard driver.isAvailable else {
            runID = nil
            state = .idle
            throw CameraSourceError.unavailable
        }

        // upright from the first frame: how this camera is mounted and how the phone is held, before
        // the camera screen's own rotation coordinator takes over
        if let device = driver.cameraDevice {
            driver.setCaptureRotation(AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
                .videoRotationAngleForHorizonLevelCapture)
        }
        let backendStream: AsyncStream<PoseFrame>
        do {
            backendStream = try await driver.start()
        } catch {
            if runID == currentID { runID = nil; state = .idle }
            throw error
        }
        guard runID == currentID else {
            await driver.stop()
            throw CameraSourceError.cancelled
        }
        endedAtLimit = false
        isSetActive = false
        state = .running
        let stream = AsyncStream(PoseFrame.self, bufferingPolicy: .bufferingNewest(3)) { continuation in
            self.continuation = continuation
        }
        forwardTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var previewFirstTime: TimeInterval?
            var setFirstTime: TimeInterval?
            var previousTime: TimeInterval?
            for await frame in backendStream {
                guard self.runID == currentID else { break }
                guard frame.time.isFinite, frame.time >= 0 else { continue }
                if let previousTime, frame.time <= previousTime { continue }
                previousTime = frame.time
                let elapsed: TimeInterval
                if self.isSetActive {
                    if setFirstTime == nil { setFirstTime = frame.time }
                    elapsed = max(0, frame.time - (setFirstTime ?? frame.time))
                } else {
                    if previewFirstTime == nil { previewFirstTime = frame.time }
                    elapsed = max(0, frame.time - (previewFirstTime ?? frame.time))
                }
                self.continuation?.yield(frame.retimed(to: elapsed))
                if self.isSetActive && elapsed >= self.setDurationLimitSeconds {
                    self.endedAtLimit = true
                    await self.stop()
                    break
                }
            }
            if self.runID == currentID {
                self.runID = nil
                self.state = .interrupted
                self.isSetActive = false
                self.limitTask?.cancel()
                self.limitTask = nil
                self.continuation?.finish()
                self.continuation = nil
                await self.driver.stop()
            }
        }
        return stream
    }

    func stop() async {
        runID = nil
        state = .idle
        isSetActive = false
        limitTask?.cancel()
        limitTask = nil
        continuation?.finish()
        continuation = nil
        forwardTask?.cancel()
        forwardTask = nil
        await driver.stop()
    }
}
