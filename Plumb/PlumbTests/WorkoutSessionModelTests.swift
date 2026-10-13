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

    /// Start at the phone, walk to the spot, squat, walk back to stop: measured and saved.
    @Test func walkingToTheSpotAndBackIsMeasuredAndSaved() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbWalkTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalSessionStore(url: directory.appending(path: "sessions.json"))
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source, store: store)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        let capture = CaptureTraces.walkIn() + CaptureTraces.squats(reps: 6, from: 2.0)
            + CaptureTraces.walkOut(from: 14.0)
        for frame in capture { source.emit(frame) }
        await model.endSet()
        guard case .measured(let analysis, _) = model.result else {
            Issue.record("Expected the set between walking in and out to be measured, got \(String(describing: model.result))")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(model.history.first?.sets.count == 1)
    }

    /// The phone stands a few steps away: the set starts once the athlete holds still in position
    /// and ends once they walk back, and every rep is said aloud.
    @Test func handsFreeSetStartsInPositionAndEndsWhenTheAthleteWalksAway() async throws {
        let source = TestPoseSource()
        let announcer = RecordingAnnouncer()
        let preferences = PlumbPreferences(defaults: UserDefaults(suiteName: "PlumbHandsFree-\(UUID())")!,
                                           handsFreeByDefault: true)
        let model = WorkoutSessionModel(source: source, preferences: preferences, announcer: announcer)
        model.handsFreeCountdown = 0
        #expect(model.handsFree)
        await model.startPreview()
        for frame in CaptureTraces.squats(reps: 0, from: 0, standing: 2.0) { source.emit(frame) }
        try await waitUntil { model.stage == .capturing }

        // The camera keeps sending frames after the athlete leaves; the set ends about 2 s later.
        for frame in CaptureTraces.squats(reps: 6, from: 2.0) + CaptureTraces.walkOut(from: 14.0, duration: 4.0) {
            source.emit(frame)
        }
        try await waitUntil { model.stage == .result }
        guard case .measured(let analysis, _) = model.result else {
            Issue.record("Expected a measured hands-free set, got \(String(describing: model.result))")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(model.endedHandsFree)
        #expect(model.liveRepCount == 6)
        #expect(announcer.phrases.filter { Int($0) != nil } == ["1", "2", "3", "4", "5", "6"])
        #expect(announcer.phrases.last == "6 reps measured")
    }

    /// Sets with movements too shallow to count: after two of them, the next set's setup names the
    /// pattern, and a third set showing it again says so.
    @Test func aRecurringPatternBecomesTheFocusAndIsRecognizedAgain() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbFocusTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalSessionStore(url: directory.appending(path: "sessions.json"))
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source, store: store)
        // Six full reps with a shallow dip (0.06 of the frame, under the 0.15 leg-length bottom) after each.
        let frames = (0...(6 * 30)).map { index -> PoseFrame in
            let phase = Double(index % 30) / 30
            let full = phase < 2.0 / 3 ? 0.20 * (1 - cos(2 * .pi * phase * 1.5)) / 2 : 0
            let dip = phase >= 2.0 / 3 ? 0.06 * (1 - cos(2 * .pi * (phase - 2.0 / 3) * 3)) / 2 : 0
            return frame(time: Double(index) * 0.1, hipY: 0.42 + full + dip)
        }
        for setNumber in 1...3 {
            #expect((model.focus != nil) == (setNumber == 3))
            await model.startPreview()
            await model.beginSet(countdown: 0)
            for frame in frames { source.emit(frame) }
            await model.endSet()
            guard case .measured = model.result else {
                Issue.record("Expected a measured set \(setNumber), got \(String(describing: model.result))")
                return
            }
            #expect((model.repeatedPattern != nil) == (setNumber == 3))
        }
        #expect(model.focus?.issue == .shallowMovements)
        #expect(model.history.first?.sets.last?.issues?.contains(.shallowMovements) == true)
    }

    @Test func handsFreeOffWaitsForTheStartButton() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        #expect(!model.handsFree)
        await model.startPreview()
        for frame in CaptureTraces.squats(reps: 0, from: 0, standing: 3.0) { source.emit(frame) }
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.stage == .framing)
        #expect(model.handsFreeProgress == 0)
        await model.cancel()
    }

    @Test func liveCountIsSaidOnlyWhenSpeechIsOn() async throws {
        let source = TestPoseSource()
        let announcer = RecordingAnnouncer()
        let preferences = PlumbPreferences(defaults: UserDefaults(suiteName: "PlumbQuiet-\(UUID())")!)
        preferences.speaksLive = false
        let model = WorkoutSessionModel(source: source, preferences: preferences, announcer: announcer)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        let frames = trace(reps: 6)
        for frame in frames { source.emit(frame) }
        try await waitUntil { model.frameCount == frames.count }
        await model.endSet()
        // The live count may still be one rep behind when Stop is tapped right after the last rep.
        #expect((5...6).contains(model.liveRepCount))
        #expect(announcer.phrases.isEmpty)
    }

    /// Returns as soon as the condition holds. The limit only bounds a real hang: on a loaded CI
    /// simulator, with many main-actor tests running at once, the live analysis of a whole set can
    /// take several seconds.
    private func waitUntil(_ condition: @MainActor () -> Bool, timeout: Duration = .seconds(30)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for the session")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
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

    @Test func aCameraStopAfterSeveralRepsKeepsWhatWasCaptured() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        let frames = trace(reps: 6)
        for frame in frames { source.emit(frame) }
        try await waitUntil { model.frameCount == frames.count }
        source.finishUnexpectedly()
        try await waitUntil { model.stage == .result }
        guard case .measured(let analysis, _) = model.result else {
            Issue.record("The captured reps should be reviewed, got \(String(describing: model.result))")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(model.endedEarly)
    }

    @Test func comparisonGapSaysWhenAnEarlierSetHadTooFewReps() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        for reps in [3, 6] {
            await model.startPreview()
            await model.beginSet(countdown: 0)
            for frame in trace(reps: reps) { source.emit(frame) }
            await model.endSet()
        }
        #expect(model.comparison == nil)
        #expect(model.comparisonGap == .tooFewReps)
    }

    @Test func retakeAdviceMatchesTheReason() async throws {
        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source)
        // Legs never in view: the general advice about keeping the joints visible applies.
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for index in 0...40 {
            source.emit(PoseFrame(time: Double(index) * 0.1, subjectCount: 1, joints: [
                .leftHip: JointPoint(x: 0.47, y: 0.42, confidence: 0.99),
            ]))
        }
        await model.endSet()
        #expect(model.retakeHint == ExerciseDefinition.squat.copy.retakeHint)
        // Too short: the reason already says what to do.
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for index in 0...5 { source.emit(frame(time: Double(index) * 0.1, hipY: 0.42)) }
        await model.endSet()
        guard case .insufficientView = model.result else {
            Issue.record("A short set must be refused")
            return
        }
        #expect(model.retakeHint == nil)
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

    @Test func angledSetKeepsCountButWithholdsRangeAdvice() async throws {
        let suite = "PlumbAngledCue-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PlumbPreferences(defaults: defaults)
        preferences.recognizesExercise = false
        preferences.checksCameraAngle = true
        let frames = (0...120).map { index -> PoseFrame in
            let phase = Double(index % 20) / 20
            let amplitude = index / 20 >= 4 ? 0.16 : 0.22
            let pose = frame(time: Double(index) * 0.1,
                             hipY: 0.42 + amplitude * (1 - cos(2 * .pi * phase)) / 2)
            return PoseFrame(time: pose.time, subjectCount: 1, joints: pose.joints,
                             profileDeviationDegrees: 45)
        }
        guard case .analyzed(let analysis) = ExerciseAnalyzer.analyze(frames, as: .squat) else {
            Issue.record("The angled set should retain measurable reps")
            return
        }
        #expect(analysis.reps.count == 6)
        #expect(CueSelector.select(from: analysis, exercise: .squat)?.kind == .rangeDecreased)

        let source = TestPoseSource()
        let model = WorkoutSessionModel(source: source, preferences: preferences)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for pose in frames { source.emit(pose) }
        await model.endSet()
        guard case .measured(let result, let cue) = model.result else {
            Issue.record("An angled view should keep its measured rep count")
            return
        }
        #expect(result.reps.count == 6)
        #expect(cue == nil)
        #expect(model.movementNote?.contains("Turn a little more side-on") == true)
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

@MainActor
private final class RecordingAnnouncer: LiveAnnouncing {
    private(set) var phrases: [String] = []
    func announce(_ text: String) { phrases.append(text) }
}

/// 13 October: push-ups filmed while Squat was chosen were refused for the squat's joints, with no
/// word about push-ups. The app now remembers the chosen exercise and says which one it saw.
@MainActor
struct ChosenExerciseTests {
    @Test func theAppRemembersTheChosenExerciseAcrossLaunches() throws {
        let defaults = try #require(UserDefaults(suiteName: "PlumbChosen-\(UUID())"))
        let preferences = PlumbPreferences(defaults: defaults, remembersExercise: true)
        let first = WorkoutSessionModel(source: TestPoseSource(), preferences: preferences)
        #expect(first.selectedExercise == .bodyweightSquat)
        first.selectedExercise = .pushUp
        let relaunched = WorkoutSessionModel(source: TestPoseSource(), preferences: preferences)
        #expect(relaunched.selectedExercise == .pushUp)

        // Tests and demo input keep starting on the squat.
        let plain = PlumbPreferences(defaults: defaults)
        #expect(WorkoutSessionModel(source: TestPoseSource(), preferences: plain).selectedExercise == .bodyweightSquat)
    }

    @Test func pushUpsFilmedWithSquatChosenSaySoInsteadOfOnlyAskingForTheLegs() async throws {
        let source = TestPoseSource()
        let defaults = try #require(UserDefaults(suiteName: "PlumbChosen-\(UUID())"))
        let model = WorkoutSessionModel(source: source, preferences: PlumbPreferences(defaults: defaults))
        model.recognizesExercise = false
        #expect(model.selectedExercise == .bodyweightSquat)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        var time = 0.0
        for _ in 0..<5 {
            var t = 0.0
            while t < 2.0 {
                let bend = 70 * (1 - cos(2 * .pi * t / 2.0)) / 2
                source.emit(CaptureTraces.pushUpFrame(time: time, elbowBend: bend, wristX: 0.62, wristY: 0.86))
                t += CaptureTraces.step
                time += CaptureTraces.step
            }
        }
        await model.endSet()
        guard case .insufficientView = model.result else {
            Issue.record("Expected the squat to be refused, got \(String(describing: model.result))")
            return
        }
        let hint = try #require(model.retakeHint)
        #expect(hint.contains("5 push-ups"))
        #expect(hint.contains("choose Push-up"))
    }

    @Test func aSquatRefusedForHiddenFeetSuggestsNoOtherExercise() async throws {
        let source = TestPoseSource()
        let defaults = try #require(UserDefaults(suiteName: "PlumbChosen-\(UUID())"))
        let model = WorkoutSessionModel(source: source, preferences: PlumbPreferences(defaults: defaults))
        model.recognizesExercise = false
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 6, from: 0) {
            source.emit(CaptureTraces.frame(time: frame.time, hipY: frame.joints[.leftHip]?.y ?? 0.42,
                                            ankleX: 0.51, legs: true, ankle: false))
        }
        await model.endSet()
        guard case .insufficientView = model.result else {
            Issue.record("Expected a refusal without ankles, got \(String(describing: model.result))")
            return
        }
        #expect(model.retakeHint?.contains("Plumb counted") != true)
    }
}
