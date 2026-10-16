import Foundation
import Testing
@testable import Finn

struct SessionStoreAndComparisonTests {
    @Test func invalidMeasurementsCannotReplaceGoodHistory() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = LocalSessionStore(url: url)
        let id = UUID()
        let good = WorkoutSessionSummary(id: id, startedAt: .now, sets: [set(sessionID: id, range: 0.4)])
        try store.save(good)
        let original = try Data(contentsOf: url)
        let bad = WorkoutSessionSummary(id: id, startedAt: .now,
                                       sets: [set(sessionID: id, range: Double.greatestFiniteMagnitude)])
        #expect(throws: SessionStoreError.invalidSession) { try store.save(bad) }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func duplicateSavedSetIDsUseTheCorruptionRecoveryFlow() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let id = UUID()
        let first = set(sessionID: id, range: 0.4)
        let corrupt = [WorkoutSessionSummary(id: id, startedAt: .now, sets: [first, first])]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = try JSONEncoder().encode(corrupt)
        try original.write(to: url)
        let store = LocalSessionStore(url: url)
        #expect(throws: SessionStoreError.corrupted) { try store.load() }
        let backup = try store.recoverCorruptStore()
        #expect(try Data(contentsOf: backup) == original)
        #expect(try store.load().isEmpty)
    }

    @Test func aClockMovedBackwardsStartsANewSession() {
        let now = Date.now
        let session = WorkoutSessionSummary(id: UUID(), startedAt: now, sets: [])
        #expect(!session.continues(at: now.addingTimeInterval(-60)))
        #expect(session.continues(at: now.addingTimeInterval(60)))
    }

    @Test func existingHistoryAndBadgesMoveIntoFinnSupportFolder() throws {
        let support = FileManager.default.temporaryDirectory
            .appending(path: "FinnMigration-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: support) }
        let previous = support.appending(path: "Plumb", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: previous, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: previous.appending(path: "sessions.json"))
        try Data("[]".utf8).write(to: previous.appending(path: "badges.json"))
        let renamed = FinnDataMigration.directory(in: support)
        #expect(renamed.lastPathComponent == "Finn")
        #expect(FileManager.default.fileExists(atPath: renamed.appending(path: "sessions.json").path))
        #expect(FileManager.default.fileExists(atPath: renamed.appending(path: "badges.json").path))
        #expect(FinnDataMigration.directory(in: support) == renamed)
    }

    @Test func summaryRoundTripStoresOnlyDerivedFacts() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = LocalSessionStore(url: url)
        let id = UUID()
        let first = set(sessionID: id, range: 0.4)
        let second = set(sessionID: id, range: 0.3)
        let session = WorkoutSessionSummary(id: id, startedAt: .now, sets: [first, second])

        try store.save(session)
        let loaded = try store.load()
        #expect(loaded.first?.sets.count == 2)
        let serialised = try String(contentsOf: url, encoding: .utf8)
        #expect(!serialised.contains("PoseFrame"))
        #expect(!serialised.contains("clipURL"))
        #expect(!serialised.contains("pixelBuffer"))
    }

    @Test(.enabled(if: fileProtectionAttributeAvailable(),
                   "This simulator does not expose file protection metadata"))
    func savedHistoryUsesCompleteFileProtection() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = LocalSessionStore(url: url)
        let id = UUID()
        try store.save(WorkoutSessionSummary(id: id, startedAt: .now,
                                             sets: [set(sessionID: id, range: 0.4)]))
        #expect(try url.resourceValues(forKeys: [.fileProtectionKey]).fileProtection == .complete)
        try store.save(WorkoutSessionSummary(id: id, startedAt: .now,
                                             sets: [set(sessionID: id, range: 0.3)]))
        #expect(try url.resourceValues(forKeys: [.fileProtectionKey]).fileProtection == .complete)
    }

    @Test(.enabled(if: fileProtectionAttributeAvailable(),
                   "This simulator does not expose file protection metadata"))
    func loadingLegacyHistoryUpgradesFileProtection() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: url, options: .atomic)
        let store = LocalSessionStore(url: url)
        #expect(try store.load().isEmpty)
        let protection = try url.resourceValues(forKeys: [.fileProtectionKey]).fileProtection
        #expect(protection == .complete)
    }

    @Test(.enabled(if: fileProtectionAttributeAvailable(),
                   "This simulator does not expose file protection metadata"))
    func loadingHistoryUpgradesExistingCorruptBackupProtection() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let backup = directory.appending(path: "sessions-corrupt-legacy.json")
        try Data("broken".utf8).write(to: backup, options: .atomic)
        #expect(try LocalSessionStore(url: url).load().isEmpty)
        let protection = try backup.resourceValues(forKeys: [.fileProtectionKey]).fileProtection
        #expect(protection == .complete)
    }

    @Test func secondSetComparisonUsesSameSession() {
        let id = UUID()
        let first = set(sessionID: id, range: 0.4)
        let second = set(sessionID: id, range: 0.3)
        let comparison = SetComparison.compare(first, second)
        #expect(comparison?.firstSetID == first.id)
        #expect(comparison?.secondSetID == second.id)
        #expect(comparison?.rangeDirection == .shorter)
    }

    @Test func incompatibleComparisonIsRejected() {
        let id = UUID()
        let first = set(sessionID: id, range: 0.4)
        let otherSession = set(sessionID: UUID(), range: 0.3)
        let wrongSide = set(sessionID: id, range: 0.3, side: .right)
        let wrongAngle = set(sessionID: id, range: 0.3, view: .front)
        let wrongRubric = set(sessionID: id, range: 0.3, rubric: "squat-side-v1")
        #expect(SetComparison.compare(first, otherSession) == nil)
        #expect(SetComparison.compare(first, wrongSide) == nil)
        #expect(SetComparison.compare(first, wrongAngle) == nil)
        #expect(SetComparison.compare(first, wrongRubric) == nil)
    }

    @Test func noClearChangeForSmallDifference() {
        let id = UUID()
        let first = set(sessionID: id, range: 0.4)
        let second = set(sessionID: id, range: 0.38)
        #expect(SetComparison.compare(first, second)?.rangeDirection == .noClearChange)
    }

    @Test func deleteSessionRemovesItsSummaries() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = LocalSessionStore(url: url)
        let firstID = UUID()
        let secondID = UUID()
        try store.save(WorkoutSessionSummary(id: firstID, startedAt: .now, sets: [set(sessionID: firstID, range: 0.4)]))
        try store.save(WorkoutSessionSummary(id: secondID, startedAt: .now, sets: [set(sessionID: secondID, range: 0.4)]))
        try store.delete(id: firstID)
        #expect(try store.load().map(\.id) == [secondID])
    }

    @Test func corruptStoreCanBeRecoveredWithoutSilentDataLoss() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: url)
        let store = LocalSessionStore(url: url)
        #expect(throws: SessionStoreError.corrupted) { try store.load() }
        let backup = try store.recoverCorruptStore()
        #expect(FileManager.default.fileExists(atPath: backup.path))
        if fileProtectionAttributeAvailable() {
            #expect(try backup.resourceValues(forKeys: [.fileProtectionKey]).fileProtection == .complete)
        }
        #expect(try store.load().isEmpty)
    }

    @Test func deleteAllRemovesRecoveredBackupToo() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: url)
        let store = LocalSessionStore(url: url)
        let backup = try store.recoverCorruptStore()
        let id = UUID()
        try store.save(WorkoutSessionSummary(id: id, startedAt: .now,
                                             sets: [set(sessionID: id, range: 0.4)]))
        try store.deleteAll()
        #expect(try store.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: backup.path))
    }

    @Test func failedBackupDeletionKeepsMainHistoryVisible() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: url)
        let backup = directory.appending(path: "sessions-corrupt-blocked.json")
        try Data("broken".utf8).write(to: backup)
        var attempts: [String] = []
        let store = LocalSessionStore(url: url, removeItem: { file in
            attempts.append(file.lastPathComponent)
            if file.lastPathComponent == backup.lastPathComponent { throw CocoaError(.fileWriteNoPermission) }
            try FileManager.default.removeItem(at: file)
        })

        #expect(throws: CocoaError.self) { try store.deleteAll() }
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(attempts == [backup.lastPathComponent])
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "FinnStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "sessions.json")
    }

    /// A push-up is accepted from any view: filmed from the front, the side the gate followed is
    /// whichever arm Vision saw better, so sides are not a key for comparing push-up sets. On
    /// 15 October a front-view set was told its earlier sets "were filmed from your other side".
    @Test func pushUpSetsCompareAcrossSidesButSquatSetsDoNot() {
        let session = UUID()
        let pushUp = ExerciseDefinition.pushUp.rubricVersion
        let left = set(sessionID: session, range: 60, side: .left, rubric: pushUp, exercise: .pushUp)
        let right = set(sessionID: session, range: 50, side: .right, rubric: pushUp, exercise: .pushUp)
        #expect(SetComparison.compare(left, right)?.rangeDirection == .shorter)
        let squatLeft = set(sessionID: session, range: 0.4, side: .left)
        let squatRight = set(sessionID: session, range: 0.3, side: .right)
        #expect(SetComparison.compare(squatLeft, squatRight) == nil)
    }

    private func set(sessionID: UUID, range: Double, side: BodySide = .left,
                     view: CameraView = .side,
                     rubric: String = SquatRubric.version, exercise: ExerciseKind = .bodyweightSquat) -> SetSummary {
        let reps = (1...6).map { number in
            RepMetric(number: number, startTime: Double(number) * 2,
                      endTime: Double(number) * 2 + 1.5,
                      normalisedHipTravel: range)
        }
        return SetSummary(id: UUID(), sessionID: sessionID, capturedAt: .now,
                          bodySide: side,
                          analysis: SetAnalysis(reps: reps, confidence: 0.95, rubricVersion: rubric),
                          cue: nil, cueResponse: .unanswered, exercise: exercise, cameraView: view)
    }
}

private func fileProtectionAttributeAvailable() -> Bool {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "FinnProtectionProbe-\(UUID().uuidString)", directoryHint: .isDirectory)
    let url = directory.appending(path: "probe")
    defer { try? FileManager.default.removeItem(at: directory) }
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: url)
        try (url as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
        return try url.resourceValues(forKeys: [.fileProtectionKey]).fileProtection == .complete
    } catch {
        return false
    }
}
