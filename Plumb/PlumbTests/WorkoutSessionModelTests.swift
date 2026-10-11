import AVFoundation
import Testing
@testable import Plumb

@MainActor
struct WorkoutSessionModelTests {
    @Test func startAndStopProducesMeasuredResult() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        #expect(model.stage == .framing)
        await model.beginSet(countdown: 0)
        #expect(model.stage == .capturing)
        for frame in trace(reps: 6) { source.emit(frame) }
        await model.endSet()
        #expect(model.isRecording == false)
        guard case .measured(let analysis, _) = model.result else {
            Issue.record("Expected a measured result")
            return
        }
        #expect(analysis.reps.count == 6)
    }

    @Test func shortSetAbstains() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        source.emit(frame(time: 0, hipY: 0.42))
        await model.endSet()
        guard case .insufficientView = model.result else {
            Issue.record("A short set must not be presented as measured")
            return
        }
    }

    @Test func backgroundStopsCapture() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        await model.backgrounded()
        #expect(model.isRecording == false)
        #expect(source.stopCount == 1)
        #expect(model.stage == .ready)
    }

    @Test func deniedPermissionDoesNotShowRecording() async throws {
        let source = TestPoseSource()
        source.startError = .denied
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        #expect(model.isRecording == false)
        guard case .error = model.stage else { Issue.record("Expected permission error"); return }
    }

    @Test func durationLimitReviewsCollectedSet() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for sample in trace(reps: 6) { source.emit(sample) }
        source.finishAtLimit()
        for _ in 0..<100 where model.stage != .result {
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard case .measured(let analysis, _) = model.result else {
            Issue.record("Time limit should review the measured set")
            return
        }
        #expect(analysis.reps.count == 6)
    }

    @Test func cancellingCountdownNeverRecords() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        let countdown = Task { await model.beginSet(countdown: 1) }
        await Task.yield()
        await model.cancel()
        await countdown.value
        #expect(model.stage == .ready)
        #expect(model.isRecording == false)
    }

    @Test func interruptedCaptureHasNoMeasuredClaim() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        source.finishUnexpectedly()
        for _ in 0..<100 where model.stage != .result {
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard case .interrupted = model.result else {
            Issue.record("Interrupted capture must not be called measured")
            return
        }
        #expect(model.isRecording == false)
    }

    @Test func stableSetHasNoCue() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for sample in trace(reps: 6) { source.emit(sample) }
        await model.endSet()
        guard case .measured(_, let cue) = model.result else {
            Issue.record("Expected measured set")
            return
        }
        #expect(cue == nil)
    }

    @Test func noCompleteRepOffersRetake() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for index in 0...40 { source.emit(frame(time: Double(index) * 0.1, hipY: 0.42)) }
        await model.endSet()
        guard case .insufficientView = model.result else {
            Issue.record("A stationary trace should offer a retake")
            return
        }
        #expect(model.currentSession == nil)
    }

    @Test func backgroundKeepsFinishedResult() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for sample in trace(reps: 6) { source.emit(sample) }
        await model.endSet()
        await model.backgrounded()
        guard case .measured = model.result else {
            Issue.record("Completed review should survive backgrounding")
            return
        }
    }

    @Test func secondSetPersistsAndComparesWithinSession() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalSessionStore(url: directory.appending(path: "sessions.json"))
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source, store: store)

        await model.startPreview()
        await model.beginSet(countdown: 0)
        for sample in trace(reps: 6, amplitude: 0.20) { source.emit(sample) }
        await model.endSet()
        let sessionID = try #require(model.currentSession?.id)

        await model.startPreview()
        await model.beginSet(countdown: 0)
        for sample in trace(reps: 6, amplitude: 0.13) { source.emit(sample) }
        await model.endSet()

        #expect(model.currentSession?.id == sessionID)
        #expect(model.currentSession?.sets.count == 2)
        #expect(model.comparison?.rangeDirection == .shorter)
        #expect(try store.load().first?.sets.count == 2)
    }

    private func trace(reps: Int, amplitude: Double = 0.20) -> [PoseFrame] {
        (0...(reps * 20)).map { index in
            let phase = Double(index % 20) / 20
            return frame(time: Double(index) * 0.1,
                         hipY: 0.42 + amplitude * (1 - cos(2 * .pi * phase)) / 2)
        }
    }

    private func frame(time: Double, hipY: Double) -> PoseFrame {
        PoseFrame(time: time, subjectCount: 1, joints: [
            .leftHip: JointPoint(x: 0.47, y: hipY, confidence: 0.99),
            .leftKnee: JointPoint(x: 0.49, y: 0.70, confidence: 0.99),
            .leftAnkle: JointPoint(x: 0.51, y: 0.90, confidence: 0.99),
            .rightHip: JointPoint(x: 0.53, y: hipY, confidence: 0.99),
            .rightKnee: JointPoint(x: 0.55, y: 0.70, confidence: 0.99),
            .rightAnkle: JointPoint(x: 0.57, y: 0.90, confidence: 0.99),
        ])
    }
}

@MainActor
private final class TestPoseSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    var endedAtLimit = false
    var startError: CameraSourceError?
    var stopCount = 0
    private var continuation: AsyncStream<PoseFrame>.Continuation?

    func start() async throws -> AsyncStream<PoseFrame> {
        if let startError { throw startError }
        return AsyncStream { continuation in self.continuation = continuation }
    }

    func stop() async {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    func emit(_ frame: PoseFrame) { continuation?.yield(frame) }

    func finishAtLimit() {
        endedAtLimit = true
        continuation?.finish()
        continuation = nil
    }

    func finishUnexpectedly() {
        continuation?.finish()
        continuation = nil
    }
}
