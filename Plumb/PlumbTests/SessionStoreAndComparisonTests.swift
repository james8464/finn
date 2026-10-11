import Foundation
import Testing
@testable import Plumb

struct SessionStoreAndComparisonTests {
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
        let serialized = try String(contentsOf: url, encoding: .utf8)
        #expect(!serialized.contains("PoseFrame"))
        #expect(!serialized.contains("clipURL"))
        #expect(!serialized.contains("pixelBuffer"))
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

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "PlumbStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "sessions.json")
    }

    private func set(sessionID: UUID, range: Double, side: BodySide = .left,
                     view: CameraView = .side,
                     rubric: String = SquatRubric.version) -> SetSummary {
        let reps = (1...6).map { number in
            RepMetric(number: number, startTime: Double(number) * 2,
                      endTime: Double(number) * 2 + 1.5,
                      normalizedHipTravel: range)
        }
        return SetSummary(id: UUID(), sessionID: sessionID, capturedAt: .now,
                          bodySide: side,
                          analysis: SetAnalysis(reps: reps, confidence: 0.95, rubricVersion: rubric),
                          cue: nil, cueResponse: .unanswered, cameraView: view)
    }
}
