import AVFoundation
import Foundation
import Testing
@testable import Plumb

/// Saving a finished session to Apple Health, with a fake in place of HealthKit.
@MainActor
struct FitnessSessionTests {
    @Test func aFinishedSessionIsSavedOnceWhenTheOptionIsOn() async throws {
        let setup = try Setup(savesToFitness: true)
        try await setup.measureASet()
        let sessionID = try #require(setup.model.history.first?.id)

        await setup.model.finishSession()
        #expect(setup.fitness.saved.count == 1)
        let workout = try #require(setup.fitness.saved.first)
        #expect(workout.sessionID == sessionID)
        #expect(workout.setCount == 1)
        #expect(workout.measuredReps == 6)
        #expect(setup.model.fitnessSave == FitnessSaveReport(sessionID: sessionID, status: .saved))
        let record = try #require(try setup.store.load().first?.fitnessWorkout)
        #expect(record.workoutID == setup.fitness.lastWorkoutID)
        #expect(setup.model.history.first?.fitnessWorkout == record)

        // Neither a retry from History nor a reopened app saves it again.
        let saved = try #require(setup.model.history.first)
        #expect(!setup.model.canSaveToFitness(saved))
        await setup.model.saveToFitness(sessionID: sessionID)
        let reopened = WorkoutSessionModel(source: TestSource(), store: setup.store,
                                           preferences: setup.preferences, fitness: setup.fitness)
        await reopened.saveToFitness(sessionID: sessionID)
        #expect(!reopened.canSaveToFitness(try #require(reopened.history.first)))
        #expect(setup.fitness.saveAttempts == 1)
    }

    @Test func nothingIsSavedAndHealthIsUntouchedWhenTheOptionIsOff() async throws {
        let setup = try Setup(savesToFitness: false)
        #expect(!setup.model.savesToFitness)
        try await setup.measureASet()
        await setup.model.finishSession()
        #expect(setup.fitness.saveAttempts == 0)
        #expect(setup.fitness.authorizationReads == 0)
        #expect(setup.fitness.requests == 0)
        #expect(setup.model.fitnessSave == nil)
        #expect(!setup.model.canSaveToFitness(try #require(setup.model.history.first)))
    }

    @Test func aSessionWithoutAMeasuredSetIsNotSaved() async throws {
        let setup = try Setup(savesToFitness: true)
        await setup.model.startPreview()
        await setup.model.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 0, from: 0, standing: 3) { setup.source.emit(frame) }
        await setup.model.endSet()
        #expect(setup.model.history.isEmpty)
        await setup.model.finishSession()
        #expect(setup.fitness.saveAttempts == 0)
        #expect(setup.model.fitnessSave == nil)
    }

    /// A second Done or a History retry while Health is still saving does not start another save.
    @Test func aSessionIsNotSavedTwiceWhileASaveIsRunning() async throws {
        let setup = try Setup(savesToFitness: true)
        try await setup.measureASet()
        let sessionID = try #require(setup.model.history.first?.id)
        setup.fitness.holdsSaves = true
        let done = Task { await setup.model.finishSession() }
        try await waitUntil { setup.fitness.saveAttempts == 1 }
        #expect(setup.model.fitnessSave?.status == .saving)
        #expect(!setup.model.canSaveToFitness(try #require(setup.model.history.first)))
        await setup.model.saveToFitness(sessionID: sessionID)
        await setup.model.finishSession()
        setup.fitness.releaseSaves()
        await done.value
        #expect(setup.fitness.saveAttempts == 1)
        #expect(setup.fitness.saved.count == 1)
        #expect(setup.model.fitnessSave?.status == .saved)
    }

    /// A failed save keeps the session, says so, and a retry from History saves it once.
    @Test func aFailedSaveIsRetriedWithoutDuplicates() async throws {
        let setup = try Setup(savesToFitness: true)
        setup.fitness.failures = [CocoaError(.fileWriteUnknown)]
        try await setup.measureASet()
        let sessionID = try #require(setup.model.history.first?.id)

        await setup.model.finishSession()
        #expect(setup.model.fitnessSave == FitnessSaveReport(sessionID: sessionID, status: .failed))
        #expect(setup.fitness.saved.isEmpty)
        let kept = try #require(try setup.store.load().first)
        #expect(kept.id == sessionID && kept.fitnessWorkout == nil && kept.sets.count == 1)
        #expect(setup.model.canSaveToFitness(kept))

        await setup.model.saveToFitness(sessionID: sessionID)
        await setup.model.saveToFitness(sessionID: sessionID)
        #expect(setup.fitness.saveAttempts == 2)
        #expect(setup.fitness.saved.count == 1)
        #expect(setup.model.fitnessSave == FitnessSaveReport(sessionID: sessionID, status: .saved))
        #expect(try setup.store.load().first?.fitnessWorkout != nil)
    }

    @Test func turningTheOptionOnAsksHealthOnceAndRemembersTheChoice() async throws {
        let setup = try Setup(savesToFitness: false, access: .notDetermined)
        setup.model.savesToFitness = true
        await setup.model.requestFitnessAccess()
        #expect(setup.fitness.requests == 1)
        #expect(setup.model.fitnessAccess == .authorized)
        await setup.model.requestFitnessAccess()
        #expect(setup.fitness.requests == 1)
        #expect(setup.preferences.savesToFitness)
    }

    /// Health denied sharing: the session stays unsaved, the line asks to allow Plumb, and a retry
    /// after allowing it saves the session.
    @Test func deniedPermissionSaysWhereToAllowItAndCanBeRetried() async throws {
        let setup = try Setup(savesToFitness: true, access: .denied)
        try await setup.measureASet()
        let sessionID = try #require(setup.model.history.first?.id)
        await setup.model.finishSession()
        #expect(setup.fitness.saveAttempts == 0)
        #expect(setup.fitness.requests == 0)
        #expect(setup.model.fitnessSave?.status == .needsPermission)
        #expect(setup.model.fitnessAccess == .denied)

        setup.fitness.access = .authorized
        setup.model.refreshFitnessAccess()
        #expect(setup.model.fitnessAccess == .authorized)
        await setup.model.saveToFitness(sessionID: sessionID)
        #expect(setup.fitness.saved.count == 1)
    }

    /// Health refused at save time (permission turned off since it was checked).
    @Test func aRefusedSaveAsksToAllowPlumb() async throws {
        let setup = try Setup(savesToFitness: true)
        setup.fitness.failures = [FitnessSaveError.notAuthorized]
        try await setup.measureASet()
        await setup.model.finishSession()
        #expect(setup.model.fitnessSave?.status == .needsPermission)
        #expect(setup.model.fitnessAccess == .denied)
    }

    @Test func noHealthOnThisDeviceSaysSo() async throws {
        let setup = try Setup(savesToFitness: true, access: .unavailable)
        try await setup.measureASet()
        await setup.model.finishSession()
        #expect(setup.fitness.saveAttempts == 0)
        #expect(setup.model.fitnessSave?.status == .unavailable)
    }

    /// Health saved the workout while the iPhone was locked and returned no identifier: the session
    /// is still marked saved.
    @Test func aSaveWithoutAnIdentifierStillCountsAsSaved() async throws {
        let setup = try Setup(savesToFitness: true)
        setup.fitness.returnsIdentifier = false
        try await setup.measureASet()
        await setup.model.finishSession()
        let record = try #require(try setup.store.load().first?.fitnessWorkout)
        #expect(record.workoutID == nil)
        await setup.model.saveToFitness(sessionID: try #require(setup.model.history.first?.id))
        #expect(setup.fitness.saveAttempts == 1)
    }

    /// Demo and recorded input have no exporter: nothing is offered or saved.
    @Test func withoutAnExporterNothingIsOffered() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbFitnessDemo-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = try #require(UserDefaults(suiteName: "PlumbFitnessDemo-\(UUID())"))
        let preferences = PlumbPreferences(defaults: defaults)
        preferences.savesToFitness = true
        let source = TestSource()
        let model = WorkoutSessionModel(source: source,
                                        store: LocalSessionStore(url: directory.appending(path: "sessions.json")),
                                        preferences: preferences)
        #expect(!model.offersFitness)
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 6, from: 0) { source.emit(frame) }
        await model.endSet()
        await model.finishSession()
        #expect(model.fitnessSave == nil)
        #expect(!model.canSaveToFitness(try #require(model.history.first)))
    }

    /// Cancel on the camera screen comes back to the first screen without Done: the session stays
    /// open there, and finishing it saves it to Apple Health once.
    @Test func aSessionLeftWithCancelIsFinishedAndSavedFromTheFirstScreen() async throws {
        let setup = try Setup(savesToFitness: true)
        try await setup.measureASet()
        let sessionID = try #require(setup.model.currentSession?.id)
        await setup.model.startPreview()
        #expect(setup.model.stage == .framing)
        #expect(setup.model.unfinishedSession == nil)
        await setup.model.cancel()
        #expect(setup.model.stage == .ready)
        #expect(setup.model.unfinishedSession?.id == sessionID)
        #expect(setup.fitness.saveAttempts == 0)

        await setup.model.finishSession()
        #expect(setup.model.unfinishedSession == nil)
        #expect(setup.model.currentSession == nil)
        #expect(setup.fitness.saved.map(\.sessionID) == [sessionID])
        #expect(setup.model.fitnessSave == FitnessSaveReport(sessionID: sessionID, status: .saved))
        #expect(try setup.store.load().first?.fitnessWorkout != nil)
    }

    /// Going to the background during a set also comes back to the first screen without Done:
    /// History can save that open session, which finishes it, so the next set starts a new one.
    @Test func aSessionLeftInTheBackgroundCanBeSavedFromHistory() async throws {
        let setup = try Setup(savesToFitness: true)
        try await setup.measureASet()
        let session = try #require(setup.model.history.first)
        await setup.model.startPreview()
        // During a capture, the session in progress is saved at Done only.
        #expect(!setup.model.canSaveToFitness(session))
        await setup.model.saveToFitness(sessionID: session.id)
        #expect(setup.fitness.saveAttempts == 0)
        #expect(setup.model.currentSession?.id == session.id)

        await setup.model.backgrounded()
        #expect(setup.model.stage == .ready)
        #expect(setup.model.unfinishedSession?.id == session.id)
        #expect(setup.model.canSaveToFitness(session))
        await setup.model.saveToFitness(sessionID: session.id)
        #expect(setup.model.currentSession == nil)
        #expect(setup.fitness.saved.map(\.sessionID) == [session.id])
        #expect(!setup.model.canSaveToFitness(try #require(setup.model.history.first)))

        setup.clock.advance(by: 60)
        try await setup.measureASet()
        #expect(setup.model.currentSession?.id != session.id)
        #expect(setup.fitness.saveAttempts == 1)
    }

    /// With the option off, the open session is not ended by a History save, and Health is untouched.
    @Test func anOpenSessionIsNotFinishedFromHistoryWhenTheOptionIsOff() async throws {
        let setup = try Setup(savesToFitness: false)
        try await setup.measureASet()
        let session = try #require(setup.model.history.first)
        await setup.model.startPreview()
        await setup.model.cancel()
        #expect(!setup.model.canSaveToFitness(session))
        await setup.model.saveToFitness(sessionID: session.id)
        #expect(setup.model.unfinishedSession?.id == session.id)
        #expect(setup.fitness.authorizationReads == 0)
    }

    /// A set long after the previous one starts a new session, so a workout never spans a day; the
    /// earlier session is saved to Apple Health then, as at Done.
    @Test func aSetAfterALongBreakStartsANewSessionAndSavesTheEarlierOne() async throws {
        let setup = try Setup(savesToFitness: true)
        try await setup.measureASet()
        let first = try #require(setup.model.currentSession?.id)
        await setup.model.startPreview()
        await setup.model.cancel()

        setup.clock.advance(by: 10 * 60)
        try await setup.measureASet(setsInSession: 2)
        #expect(setup.model.currentSession?.id == first)
        #expect(setup.fitness.saveAttempts == 0)

        setup.clock.advance(by: WorkoutSessionSummary.longestBreak + 60)
        try await setup.measureASet()
        let second = try #require(setup.model.currentSession?.id)
        #expect(second != first)
        #expect(setup.model.comparison == nil)
        try await waitUntil { setup.model.fitnessRecord(forSession: first) != nil }
        let workout = try #require(setup.fitness.saved.first)
        #expect(workout.sessionID == first)
        #expect(workout.setCount == 2)
        #expect(workout.end < setup.clock.date.addingTimeInterval(-WorkoutSessionSummary.longestBreak))
        #expect(try setup.store.load().first(where: { $0.id == first })?.fitnessWorkout != nil)

        await setup.model.finishSession()
        #expect(setup.fitness.saved.map(\.sessionID) == [first, second])
        #expect(setup.fitness.saved.last?.setCount == 1)
    }

    /// Plumb never deletes Health data, so the delete dialogs say a saved workout stays in Health:
    /// only for a session saved there (also after reopening), never for one that is not.
    @Test func deletingSaysASavedWorkoutStaysInHealth() async throws {
        let setup = try Setup(savesToFitness: true)
        setup.fitness.failures = [CocoaError(.fileWriteUnknown)]
        try await setup.measureASet()
        let unsaved = try #require(setup.model.currentSession?.id)
        await setup.model.finishSession()
        #expect(setup.model.fitnessSave?.status == .failed)
        #expect(!setup.model.leavesHealthWorkout(forSession: unsaved))
        #expect(!setup.model.leavesHealthWorkouts)

        setup.clock.advance(by: 60)
        try await setup.measureASet()
        let saved = try #require(setup.model.currentSession?.id)
        await setup.model.finishSession()
        #expect(setup.model.leavesHealthWorkout(forSession: saved))
        #expect(!setup.model.leavesHealthWorkout(forSession: unsaved))
        #expect(setup.model.leavesHealthWorkouts)

        let reopened = WorkoutSessionModel(source: TestSource(), store: setup.store,
                                           preferences: setup.preferences, fitness: setup.fitness)
        #expect(reopened.leavesHealthWorkout(forSession: saved))
        #expect(!reopened.leavesHealthWorkout(forSession: unsaved))
        #expect(reopened.leavesHealthWorkouts)

        // Once the saved session is deleted, deleting the rest leaves nothing more in Health.
        setup.model.deleteHistory(id: saved)
        #expect(!setup.model.leavesHealthWorkouts)
        #expect(setup.model.history.map(\.id) == [unsaved])
        #expect(setup.fitness.saved.map(\.sessionID) == [saved])
    }

    /// A save still running when the session is deleted finishes in Health: the dialog says so,
    /// and the deleted session is not written back to history.
    @Test func aSaveStillRunningCountsAsAWorkoutThatStays() async throws {
        let setup = try Setup(savesToFitness: true)
        try await setup.measureASet()
        let id = try #require(setup.model.currentSession?.id)
        setup.fitness.holdsSaves = true
        let done = Task { await setup.model.finishSession() }
        try await waitUntil { setup.fitness.saveAttempts == 1 }
        #expect(setup.model.leavesHealthWorkout(forSession: id))
        #expect(setup.model.leavesHealthWorkouts)

        setup.model.deleteHistory(id: id)
        setup.fitness.releaseSaves()
        await done.value
        #expect(setup.fitness.saved.map(\.sessionID) == [id])
        #expect(try setup.store.load().isEmpty)
        #expect(setup.model.history.isEmpty)
    }

    /// No Done after the last set, then iOS terminates Plumb (swiped away, or reclaimed in the
    /// background). On the next launch the first screen still offers to finish the session, a set a
    /// few minutes later joins it, and Done saves it to Apple Health once.
    @Test func anOpenSessionSurvivesARelaunch() async throws {
        let setup = try Setup(savesToFitness: true)
        try await setup.measureASet()
        let id = try #require(setup.model.currentSession?.id)

        let clock = setup.clock
        let source = TestSource()
        let relaunched = WorkoutSessionModel(source: source, store: setup.store, preferences: setup.preferences,
                                             fitness: setup.fitness, currentDate: { clock.date })
        #expect(relaunched.unfinishedSession?.id == id)

        clock.advance(by: 5 * 60)
        await relaunched.startPreview()
        await relaunched.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 6, from: 0) { source.emit(frame) }
        await relaunched.endSet()
        #expect(relaunched.currentSession?.id == id)
        #expect(relaunched.currentSession?.sets.count == 2)
        #expect(relaunched.comparison != nil)

        await relaunched.finishSession()
        #expect(setup.fitness.saved.map(\.sessionID) == [id])
        let again = WorkoutSessionModel(source: TestSource(), store: setup.store, preferences: setup.preferences,
                                        fitness: setup.fitness, currentDate: { clock.date })
        #expect(again.unfinishedSession == nil)
    }

    /// Sessions saved before Plumb marked open ones are treated as finished: a relaunch does not
    /// offer to finish every old session.
    @Test func anOlderSessionWithoutTheOpenMarkIsNotReopened() throws {
        let setup = try Setup(savesToFitness: true)
        let old = WorkoutSessionSummary(id: UUID(), startedAt: setup.clock.date, sets: [])
        try setup.store.save(old)
        let relaunched = WorkoutSessionModel(source: TestSource(), store: setup.store, preferences: setup.preferences,
                                             fitness: setup.fitness)
        #expect(relaunched.history.map(\.id) == [old.id])
        #expect(relaunched.unfinishedSession == nil)
    }

    /// Done failed to save to Health, then the person deletes that session, or all data. The first
    /// screen no longer offers "Couldn't save to Fitness · Try again" for a session that is gone,
    /// where Try again did nothing.
    @Test func deletingASessionClearsItsFailedSave() async throws {
        for deletesAll in [false, true] {
            let setup = try Setup(savesToFitness: true)
            setup.fitness.failures = [CocoaError(.fileWriteUnknown)]
            try await setup.measureASet()
            let id = try #require(setup.model.currentSession?.id)
            await setup.model.finishSession()
            #expect(setup.model.fitnessSave == FitnessSaveReport(sessionID: id, status: .failed))
            if deletesAll { setup.model.deleteAllData() } else { setup.model.deleteHistory(id: id) }
            #expect(setup.model.fitnessSave == nil, "delete all: \(deletesAll)")
        }
    }

    /// A save still running when its session is deleted, which then fails: there was never a
    /// workout in Health, and nothing is left to retry.
    @Test func aSaveFailingAfterItsSessionWasDeletedLeavesNoRetry() async throws {
        let setup = try Setup(savesToFitness: true)
        try await setup.measureASet()
        let id = try #require(setup.model.currentSession?.id)
        setup.fitness.holdsSaves = true
        setup.fitness.failures = [CocoaError(.fileWriteUnknown)]
        let done = Task { await setup.model.finishSession() }
        try await waitUntil { setup.fitness.saveAttempts == 1 }
        setup.model.deleteHistory(id: id)
        #expect(setup.model.fitnessSave == FitnessSaveReport(sessionID: id, status: .saving))
        setup.fitness.releaseSaves()
        await done.value
        #expect(setup.model.fitnessSave == nil)
    }

    @Test func aSessionContinuesUpToTheLongestBreak() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let empty = WorkoutSessionSummary(id: UUID(), startedAt: start, sets: [])
        #expect(empty.continues(at: start.addingTimeInterval(WorkoutSessionSummary.longestBreak)))
        #expect(!empty.continues(at: start.addingTimeInterval(WorkoutSessionSummary.longestBreak + 1)))
        #expect(empty.continues(at: start.addingTimeInterval(-60)))
    }

    /// Returns as soon as the condition holds. The limit only bounds a real hang: on a loaded CI
    /// simulator, with many main-actor tests running at once, the live analysis of a whole set can
    /// take several seconds.
    private func waitUntil(_ condition: @MainActor () -> Bool, timeout: Duration = .seconds(30)) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for the condition")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

/// A model with a local store, its own options, and a fake Health exporter.
@MainActor
private final class Setup {
    let directory: URL
    let store: LocalSessionStore
    let preferences: PlumbPreferences
    let fitness: FakeFitnessExporter
    let source = TestSource()
    let clock = TestClock()
    let model: WorkoutSessionModel

    init(savesToFitness: Bool, access: FitnessAuthorization = .authorized) throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbFitness-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = LocalSessionStore(url: directory.appending(path: "sessions.json"))
        let defaults = try #require(UserDefaults(suiteName: "PlumbFitness-\(UUID())"))
        preferences = PlumbPreferences(defaults: defaults)
        preferences.savesToFitness = savesToFitness
        fitness = FakeFitnessExporter(access: access)
        let clock = clock
        model = WorkoutSessionModel(source: source, store: store, preferences: preferences, fitness: fitness,
                                    currentDate: { clock.date })
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    /// One measured six-rep squat set, saved to history in the current session.
    func measureASet(setsInSession: Int = 1) async throws {
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 6, from: 0) { source.emit(frame) }
        await model.endSet()
        guard case .measured(let analysis, _) = model.result, analysis.reps.count == 6 else {
            Issue.record("Expected six measured reps, got \(String(describing: model.result))")
            return
        }
        let session = try #require(model.currentSession)
        #expect(session.sets.count == setsInSession)
        #expect(model.history.first(where: { $0.id == session.id })?.sets.count == setsInSession)
    }
}

/// The date of each measured set, moved forward by the tests.
@MainActor
private final class TestClock {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(by interval: TimeInterval) { date = date.addingTimeInterval(interval) }
}

@MainActor
private final class FakeFitnessExporter: FitnessWorkoutSaving {
    var access: FitnessAuthorization
    /// What the person answers on Health's sheet.
    var grantsOnRequest: FitnessAuthorization = .authorized
    /// Errors thrown by the next saves, in order.
    var failures: [Error] = []
    var returnsIdentifier = true
    /// Keeps saves waiting until `releaseSaves()`.
    var holdsSaves = false
    private(set) var saved: [FitnessWorkout] = []
    private(set) var saveAttempts = 0
    private(set) var authorizationReads = 0
    private(set) var requests = 0
    private(set) var lastWorkoutID: UUID?
    private var held: [CheckedContinuation<Void, Never>] = []

    init(access: FitnessAuthorization) { self.access = access }

    var authorization: FitnessAuthorization {
        authorizationReads += 1
        return access
    }

    func requestAuthorization() async -> FitnessAuthorization {
        requests += 1
        if access == .notDetermined { access = grantsOnRequest }
        return access
    }

    func save(_ workout: FitnessWorkout) async throws -> UUID? {
        saveAttempts += 1
        if holdsSaves { await withCheckedContinuation { held.append($0) } }
        if !failures.isEmpty { throw failures.removeFirst() }
        saved.append(workout)
        let id = returnsIdentifier ? UUID() : nil
        lastWorkoutID = id
        return id
    }

    func releaseSaves() {
        holdsSaves = false
        let waiting = held
        held = []
        for continuation in waiting { continuation.resume() }
    }
}

@MainActor
private final class TestSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    private var continuation: AsyncStream<PoseFrame>.Continuation?

    func start() async throws -> AsyncStream<PoseFrame> {
        AsyncStream { continuation in self.continuation = continuation }
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
    }

    func emit(_ frame: PoseFrame) { continuation?.yield(frame) }
}
