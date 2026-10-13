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

    private func waitUntil(_ condition: @MainActor () -> Bool, timeout: Duration = .seconds(5)) async throws {
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
    let model: WorkoutSessionModel

    init(savesToFitness: Bool, access: FitnessAuthorization = .authorized) throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "PlumbFitness-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = LocalSessionStore(url: directory.appending(path: "sessions.json"))
        let defaults = try #require(UserDefaults(suiteName: "PlumbFitness-\(UUID())"))
        preferences = PlumbPreferences(defaults: defaults)
        preferences.savesToFitness = savesToFitness
        fitness = FakeFitnessExporter(access: access)
        model = WorkoutSessionModel(source: source, store: store, preferences: preferences, fitness: fitness)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    /// One measured six-rep squat set, saved to history.
    func measureASet() async throws {
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 6, from: 0) { source.emit(frame) }
        await model.endSet()
        guard case .measured(let analysis, _) = model.result, analysis.reps.count == 6 else {
            Issue.record("Expected six measured reps, got \(String(describing: model.result))")
            return
        }
        #expect(model.history.first?.sets.count == 1)
    }
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
