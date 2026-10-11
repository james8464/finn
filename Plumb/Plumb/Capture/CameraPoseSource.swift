import AVFoundation

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
}

nonisolated enum CameraSourceState: Equatable {
    case idle
    case running
    case interrupted
}

@MainActor
final class CameraPoseSource {
    private let authorize: @MainActor () async -> Bool
    private let driver: any CameraCaptureDriving
    private var runID: UUID?
    private var continuation: AsyncStream<PoseFrame>.Continuation?
    private var forwardTask: Task<Void, Never>?

    private(set) var state: CameraSourceState = .idle
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

    func start() async throws -> AsyncStream<PoseFrame> {
        guard state != .running else { throw CameraSourceError.alreadyRunning }
        guard await authorize() else { throw CameraSourceError.denied }
        guard driver.isAvailable else { throw CameraSourceError.unavailable }

        let backendStream = try await driver.start()
        let currentID = UUID()
        runID = currentID
        state = .running
        let stream = AsyncStream(PoseFrame.self, bufferingPolicy: .bufferingNewest(3)) { continuation in
            self.continuation = continuation
        }
        forwardTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var firstTime: TimeInterval?
            for await frame in backendStream {
                guard self.runID == currentID else { break }
                if firstTime == nil { firstTime = frame.time }
                let elapsed = max(0, frame.time - (firstTime ?? frame.time))
                self.continuation?.yield(PoseFrame(
                    time: elapsed,
                    subjectCount: frame.subjectCount,
                    joints: frame.joints
                ))
                if elapsed >= 120 {
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
        continuation?.finish()
        continuation = nil
        forwardTask?.cancel()
        forwardTask = nil
        await driver.stop()
    }
}
