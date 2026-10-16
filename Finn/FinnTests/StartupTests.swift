import Foundation
import Testing
@testable import Finn

@MainActor
struct StartupTests {
    @Test func preparedHistoryRestoresOpenSessionWithoutReadingTwice() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "sessions.json")
        let store = LocalSessionStore(url: url)
        let session = WorkoutSessionSummary(id: UUID(), startedAt: .now, sets: [], isOpen: true)
        try store.save(session)
        let snapshot = FinnStartupSnapshot.load(
            historyURL: url,
            badgesURL: folder.appending(path: "badges.json")
        )
        // the model must use the prepared result even if the file changes before it mounts
        try Data("invalid".utf8).write(to: url)
        let model = WorkoutSessionModel(
            source: DemoPoseSource(),
            store: store,
            initialHistory: snapshot.history
        )
        #expect(model.history == [session])
        #expect(model.currentSession == session)
        #expect(model.historyIssue == nil)
    }

    @Test func failedPreparationKeepsRecoveryAvailable() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "sessions.json")
        try Data("invalid".utf8).write(to: url)
        let snapshot = FinnStartupSnapshot.load(
            historyURL: url,
            badgesURL: folder.appending(path: "badges.json")
        )
        let model = WorkoutSessionModel(
            source: DemoPoseSource(),
            store: LocalSessionStore(url: url),
            initialHistory: snapshot.history
        )
        #expect(model.historyIssue == .corrupted)
        #expect(try String(contentsOf: url, encoding: .utf8) == "invalid")
    }

    @Test func badgesSurvivePreparation() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "badges.json")
        let badge = EarnedBadge(kind: .firstSet, earnedAt: .now, detail: "5 reps")
        try LocalBadgeStore(url: url).save([badge])
        let snapshot = FinnStartupSnapshot.load(
            historyURL: folder.appending(path: "sessions.json"),
            badgesURL: url
        )
        let ledger = BadgeLedger(store: MemoryBadgeStore(), initialEarned: snapshot.badges)
        #expect(ledger.earned == [badge])
        #expect(try snapshot.history.get().isEmpty)
    }
}
