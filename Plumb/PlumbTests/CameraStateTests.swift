import AVFoundation
import Testing
@testable import Plumb

@MainActor
struct CameraStateTests {
    @Test func cameraDeniedDoesNotStartCapture() async {
        let driver = FakeCaptureDriver()
        let source = CameraPoseSource(authorize: { false }, driver: driver)

        do {
            _ = try await source.start()
            Issue.record("Denied camera access must fail")
        } catch let error as CameraSourceError {
            #expect(error == .denied)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(driver.startCount == 0)
        #expect(source.state == .idle)
    }

    @Test func unavailableCameraDoesNotStartCapture() async {
        let driver = FakeCaptureDriver()
        driver.isAvailable = false
        let source = CameraPoseSource(authorize: { true }, driver: driver)

        do {
            _ = try await source.start()
            Issue.record("Unavailable camera must fail")
        } catch let error as CameraSourceError {
            #expect(error == .unavailable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(driver.startCount == 0)
    }

    @Test func interruptionFinishesStream() async throws {
        let driver = FakeCaptureDriver()
        let source = CameraPoseSource(authorize: { true }, driver: driver)
        let stream = try await source.start()
        var iterator = stream.makeAsyncIterator()
        driver.finish()

        #expect(await iterator.next() == nil)
        #expect(source.state == .interrupted)
    }

    @Test func restartUsesFreshTimeBaseAndNoOldFrames() async throws {
        let driver = FakeCaptureDriver()
        let source = CameraPoseSource(authorize: { true }, driver: driver)
        let first = try await source.start()
        var firstIterator = first.makeAsyncIterator()
        driver.emit(frame(time: 25))
        #expect(await firstIterator.next()?.time == 0)
        await source.stop()
        #expect(await firstIterator.next() == nil)

        let second = try await source.start()
        var secondIterator = second.makeAsyncIterator()
        driver.emit(frame(time: 101))
        #expect(await secondIterator.next()?.time == 0)
        #expect(driver.startCount == 2)
        await source.stop()
    }

    @Test func captureStopsAtTwoMinutes() async throws {
        let driver = FakeCaptureDriver()
        let source = CameraPoseSource(authorize: { true }, driver: driver)
        let stream = try await source.start()
        var iterator = stream.makeAsyncIterator()
        driver.emit(frame(time: 25))
        #expect(await iterator.next()?.time == 0)
        driver.emit(frame(time: 145))
        #expect(await iterator.next()?.time == 120)
        #expect(await iterator.next() == nil)
        #expect(source.state == .idle)
    }

    private func frame(time: Double) -> PoseFrame {
        PoseFrame(time: time, subjectCount: 1, joints: [:])
    }
}

@MainActor
private final class FakeCaptureDriver: CameraCaptureDriving {
    let session = AVCaptureSession()
    var isAvailable = true
    var startCount = 0
    private var continuation: AsyncStream<PoseFrame>.Continuation?

    func start() async throws -> AsyncStream<PoseFrame> {
        startCount += 1
        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
    }

    func emit(_ frame: PoseFrame) {
        continuation?.yield(frame)
    }

    func finish() {
        continuation?.finish()
        continuation = nil
    }
}
