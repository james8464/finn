import AVFoundation
import Testing
@testable import Plumb

@MainActor
struct WorkoutSessionModelTests {
    @Test func framingFeedbackNeedsStableVisibleLandmarksAndClearsOnLoss() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        #expect(model.framingStatus == .checking)

        for index in 0..<5 { source.emit(frame(time: Double(index) * 0.1, hipY: 0.42)) }
        for _ in 0..<30 where model.framingStatus != .landmarksVisible {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.framingStatus == .landmarksVisible)

        for index in 5..<10 {
            source.emit(PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: [:]))
        }
        for _ in 0..<30 where model.framingStatus != .adjustPosition {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.framingStatus == .adjustPosition)
        await model.cancel()
        #expect(model.framingStatus == .checking)
    }

    @Test func framingFeedbackExpiresWhenCameraFramesStop() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        for index in 0..<5 { source.emit(frame(time: Double(index) * 0.1, hipY: 0.42)) }
        for _ in 0..<30 where model.framingStatus != .landmarksVisible {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.framingStatus == .landmarksVisible)
        try await Task.sleep(for: .milliseconds(1_600))
        #expect(model.framingStatus == .checking)
        await model.cancel()
    }

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

    @Test func stopTimingUsesTapInstantAndClearsForNextSet() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in trace(reps: 6) { source.emit(frame) }
        let tappedAt = ContinuousClock.now.advanced(by: .milliseconds(-20))
        await model.endSet(tappedAt: tappedAt)
        #expect((model.lastStopToResultMilliseconds ?? -1) >= 20)
        await model.startPreview()
        #expect(model.lastStopToResultMilliseconds == nil)
        await model.cancel()
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
        #expect(model.stage == .error(.permissionDenied))
    }

    @Test func unavailableCameraDoesNotOfferSettingsRecovery() async throws {
        let source = TestPoseSource()
        source.startError = .unavailable
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        #expect(model.stage == .error(.unavailable))
        #expect(model.isRecording == false)
        #expect(CameraIssue.unavailable.offersSettings == false)
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
        #expect(model.lastStopToResultMilliseconds == nil)
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

    @Test func temporarilyUnavailableHistoryCanRetryAndSaveCurrentSet() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbUnavailableStore-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "sessions.json", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        let store = LocalSessionStore(url: storeURL)
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source, store: store)
        #expect(model.historyIssue == .unavailable)

        await model.startPreview()
        await model.beginSet(countdown: 0)
        for sample in trace(reps: 6) { source.emit(sample) }
        await model.endSet()
        let pendingID = try #require(model.currentSession?.id)
        #expect(model.currentSession?.sets.count == 1)
        #expect(model.historyIssue == .unavailable)

        model.recoverHistory()
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
        #expect(model.historyIssue == .unavailable)

        await model.finishSession()
        #expect(model.currentSession == nil)
        try FileManager.default.removeItem(at: storeURL)
        model.retryHistory()
        #expect(model.historyIssue == nil)
        #expect(model.history.first?.id == pendingID)
        #expect(try store.load().first?.sets.count == 1)
    }

    @Test func corruptHistoryNeedsExplicitRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbCorruptModelStore-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "sessions.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: storeURL)
        let model = WorkoutSessionModel(source: TestPoseSource(),
                                        store: LocalSessionStore(url: storeURL))
        #expect(model.historyIssue == .corrupted)
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
        model.retryHistory()
        #expect(model.historyIssue == .corrupted)
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
        model.recoverHistory()
        #expect(model.historyIssue == nil)
        #expect(!FileManager.default.fileExists(atPath: storeURL.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .contains(where: { $0.hasPrefix("sessions-corrupt-") }))
    }

    @Test func failedDeleteAllNeverResavesAnUnsavedSet() async throws {
        let store = ToggleSessionStore()
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source, store: store)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for sample in trace(reps: 6) { source.emit(sample) }
        await model.endSet()
        #expect(model.historyIssue == .unavailable)
        #expect(model.currentSession?.sets.count == 1)

        model.deleteAllData()
        #expect(model.historyIssue == .unavailable)
        store.blocked = false
        model.retryHistory()
        #expect(model.historyIssue == nil)
        #expect(model.history.isEmpty)
        #expect(try store.load().isEmpty)
    }

    @Test func failedDeleteOneNeverResavesThatPendingSet() async throws {
        let store = ToggleSessionStore()
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source, store: store)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for sample in trace(reps: 6) { source.emit(sample) }
        await model.endSet()
        let id = try #require(model.currentSession?.id)

        model.deleteHistory(id: id)
        #expect(model.historyIssue == .unavailable)
        store.blocked = false
        model.retryHistory()
        #expect(model.historyIssue == nil)
        #expect(model.history.isEmpty)
        #expect(try store.load().isEmpty)
    }

    @Test func partiallyFailedDeleteAllIsRetriedBeforeReportingSuccess() throws {
        let store = ToggleSessionStore()
        store.blocked = false
        let id = UUID()
        try store.save(WorkoutSessionSummary(id: id, startedAt: .now, sets: []))
        let model = WorkoutSessionModel(source: TestPoseSource(), store: store)
        #expect(model.history.count == 1)

        store.failNextDeleteAllAfterClearing = true
        model.deleteAllData()
        #expect(model.historyIssue == .unavailable)
        #expect(store.deleteAllAttempts == 1)
        model.retryHistory()
        #expect(store.deleteAllAttempts == 2)
        #expect(model.historyIssue == nil)
        #expect(model.history.isEmpty)
    }

    @Test func failedDeleteOneIsRetriedOnExistingSavedSession() throws {
        let store = ToggleSessionStore()
        store.blocked = false
        let id = UUID()
        try store.save(WorkoutSessionSummary(id: id, startedAt: .now, sets: []))
        let model = WorkoutSessionModel(source: TestPoseSource(), store: store)
        #expect(model.history.map(\.id) == [id])

        store.blocked = true
        model.deleteHistory(id: id)
        #expect(model.historyIssue == .unavailable)
        store.blocked = false
        model.retryHistory()
        #expect(model.historyIssue == nil)
        #expect(model.history.isEmpty)
        #expect(try store.load().isEmpty)
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

nonisolated private final class ToggleSessionStore: SessionStoring, @unchecked Sendable {
    nonisolated(unsafe) var blocked = true
    nonisolated(unsafe) var failNextDeleteAllAfterClearing = false
    private(set) var deleteAllAttempts = 0
    private var sessions: [WorkoutSessionSummary] = []

    func load() throws -> [WorkoutSessionSummary] {
        if blocked { throw CocoaError(.fileReadNoPermission) }
        return sessions
    }

    func save(_ session: WorkoutSessionSummary) throws {
        if blocked { throw CocoaError(.fileWriteNoPermission) }
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func delete(id: UUID) throws {
        if blocked { throw CocoaError(.fileWriteNoPermission) }
        sessions.removeAll { $0.id == id }
    }

    func deleteAll() throws {
        deleteAllAttempts += 1
        if blocked { throw CocoaError(.fileWriteNoPermission) }
        sessions = []
        if failNextDeleteAllAfterClearing {
            failNextDeleteAllAfterClearing = false
            throw CocoaError(.fileWriteUnknown)
        }
    }

    func recoverCorruptStore() throws -> URL { throw SessionStoreError.notCorrupted }
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
