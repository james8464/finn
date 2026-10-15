import Foundation
import Observation

/// Where earned badges are kept. The app writes a JSON file next to the history; tests use memory.
nonisolated protocol BadgeStoring: Sendable {
    func load() throws -> [EarnedBadge]
    func save(_ badges: [EarnedBadge]) throws
}

nonisolated struct LocalBadgeStore: BadgeStoring {
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FinnDataMigration.directory(in:
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
            .appending(path: "badges.json")
    }

    func load() throws -> [EarnedBadge] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([EarnedBadge].self, from: Data(contentsOf: url))
    }

    func save(_ badges: [EarnedBadge]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(badges).write(to: url, options: [.atomic, .completeFileProtection])
    }
}

/// Keeps badges in memory only, for tests and demo input.
final class MemoryBadgeStore: BadgeStoring, @unchecked Sendable {
    private var badges: [EarnedBadge]
    init(_ badges: [EarnedBadge] = []) { self.badges = badges }
    func load() throws -> [EarnedBadge] { badges }
    func save(_ badges: [EarnedBadge]) throws { self.badges = badges }
}

/// The badges the person has, and the ones just earned, to show once at the end of a set.
/// A badge given once is never given again, even if the history later changes.
@MainActor @Observable
final class BadgeLedger {
    private(set) var earned: [EarnedBadge] = []
    /// Badges earned by the latest `update`, shown on the result until `acknowledge`.
    private(set) var justEarned: [EarnedBadge] = []
    @ObservationIgnored private let store: any BadgeStoring

    init(store: any BadgeStoring = LocalBadgeStore()) {
        self.store = store
        earned = (try? store.load()) ?? []
    }

    /// The badges in display order, earned ones with their date, the rest locked.
    var all: [(kind: BadgeKind, earned: EarnedBadge?)] {
        BadgeKind.all.map { kind in (kind, earned.first { $0.kind == kind }) }
    }

    var count: Int { earned.count }

    func has(_ kind: BadgeKind) -> Bool { earned.contains { $0.kind == kind } }

    /// Compares the history with what was already given and keeps the new ones. Returns them.
    /// Only the badges that `celebrating`, the set just saved, earned itself go to `justEarned`;
    /// the rest (at launch, after an update or an import, or a record set by an older set) are
    /// written down quietly. A set that earned nothing shows nothing, even if the launch found
    /// badges in the history.
    @discardableResult
    func update(history: [WorkoutSessionSummary], calendar: Calendar = .current,
                celebrating setID: UUID? = nil) -> [EarnedBadge] {
        let supported = BadgeRules.evaluate(history: history, calendar: calendar)
        let fresh = supported.filter { badge in !earned.contains { $0.kind == badge.kind } }
        justEarned = fresh.filter { $0.setID != nil && $0.setID == setID }
        guard !fresh.isEmpty else { return [] }
        earned.append(contentsOf: fresh)
        earned.sort { $0.earnedAt < $1.earnedAt }
        try? store.save(earned)
        return fresh
    }

    func acknowledge() { justEarned = [] }

    /// Forgets every badge, for "Delete all local data".
    func reset() {
        earned = []
        justEarned = []
        try? store.save([])
    }
}
