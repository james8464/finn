import AVFoundation

@MainActor
protocol PoseStreaming: AnyObject {
    var previewSession: AVCaptureSession { get }
    var endedAtLimit: Bool { get }
    func prepareForSet() async
    func start() async throws -> AsyncStream<PoseFrame>
    func stop() async
}

extension PoseStreaming {
    var endedAtLimit: Bool { false }
    func prepareForSet() async {}
}

@MainActor
protocol CameraCaptureDriving: AnyObject {
    var session: AVCaptureSession { get }
    var isAvailable: Bool { get }
    func start() async throws -> AsyncStream<PoseFrame>
    func stop() async
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
    private let authorize: @MainActor () async -> Bool
    private let driver: any CameraCaptureDriving
    private var runID: UUID?
    private var continuation: AsyncStream<PoseFrame>.Continuation?
    private var forwardTask: Task<Void, Never>?
    private var isSetActive = false

    private(set) var state: CameraSourceState = .idle
    private(set) var endedAtLimit = false
    var previewSession: AVCaptureSession { driver.session }

    init(authorize: @escaping @MainActor () async -> Bool, driver: any CameraCaptureDriving) {
        self.authorize = authorize
        self.driver = driver
    }

    static func live() -> CameraPoseSource {
        CameraPoseSource(authorize: {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return true
            case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
            default: return false
            }
        }, driver: AVCameraCaptureDriver())
    }

    func prepareForSet() async {
        if state == .running { isSetActive = true }
    }

    func start() async throws -> AsyncStream<PoseFrame> {
        guard state != .running && state != .starting else { throw CameraSourceError.alreadyRunning }
        let currentID = UUID()
        runID = currentID
        state = .starting
        guard await authorize() else {
            if runID == currentID { runID = nil; state = .idle }
            throw CameraSourceError.denied
        }
        guard runID == currentID else { throw CameraSourceError.cancelled }
        guard driver.isAvailable else {
            runID = nil
            state = .idle
            throw CameraSourceError.unavailable
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
            for await frame in backendStream {
                guard self.runID == currentID else { break }
                let elapsed: TimeInterval
                if self.isSetActive {
                    if setFirstTime == nil { setFirstTime = frame.time }
                    elapsed = max(0, frame.time - (setFirstTime ?? frame.time))
                } else {
                    if previewFirstTime == nil { previewFirstTime = frame.time }
                    elapsed = max(0, frame.time - (previewFirstTime ?? frame.time))
                }
                self.continuation?.yield(PoseFrame(
                    time: elapsed,
                    subjectCount: frame.subjectCount,
                    joints: frame.joints
                ))
                if self.isSetActive && elapsed >= 120 {
                    self.endedAtLimit = true
                    await self.stop()
                    break
                }
            }
            if self.runID == currentID {
                self.runID = nil
                self.state = .interrupted
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
        continuation?.finish()
        continuation = nil
        forwardTask?.cancel()
        forwardTask = nil
        await driver.stop()
    }
}
