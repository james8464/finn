import Foundation
import os

nonisolated enum SessionStoreError: Error, Equatable {
    case corrupted
    case notCorrupted
    case invalidSession
}

nonisolated protocol SessionStoring {
    func load() throws -> [WorkoutSessionSummary]
    func save(_ session: WorkoutSessionSummary) throws
    func delete(id: UUID) throws
    func deleteAll() throws
    func recoverCorruptStore() throws -> URL
}

/// Move existing on-device history and badges into the renamed support folder.
/// If a move fails, callers continue using the legacy folder so no data disappears.
nonisolated enum FinnDataMigration {
    /// Resolved once per support folder. The history and the badges are created independently, and
    /// they must agree on the folder: a second migration attempt would either fail or split the two
    /// files across the old and new paths.
    private static let resolved = OSAllocatedUnfairLock<[URL: URL]>(initialState: [:])

    static func directory(in support: URL, fileManager: FileManager = .default) -> URL {
        // the lock takes a Sendable capture; the box is the thread-safe FileManager it holds
        let files = FileManagerBox(manager: fileManager)
        return resolved.withLock { known in
            if let directory = known[support] {
                return directory
            }
            let directory = migrate(in: support, fileManager: files.manager)
            known[support] = directory
            return directory
        }
    }

    /// FileManager answers the same way from any thread for the calls `migrate` makes.
    private struct FileManagerBox: @unchecked Sendable {
        let manager: FileManager
    }

    private static func migrate(in support: URL, fileManager: FileManager) -> URL {
        let current = support.appending(path: "Finn", directoryHint: .isDirectory)
        let previous = support.appending(path: "Plumb", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: previous.path) else {
            return current
        }
        do {
            if !fileManager.fileExists(atPath: current.path) {
                try fileManager.moveItem(at: previous, to: current)
            } else {
                for item in try fileManager.contentsOfDirectory(
                    at: previous,
                    includingPropertiesForKeys: nil
                ) {
                    let destination = current.appending(path: item.lastPathComponent)
                    if !fileManager.fileExists(atPath: destination.path) {
                        try fileManager.moveItem(at: item, to: destination)
                    }
                }
            }
            return current
        } catch {
            return previous
        }
    }
}

nonisolated struct LocalSessionStore: SessionStoring {
    let url: URL
    private let removeItem: (URL) throws -> Void

    init(
        url: URL? = nil,
        removeItem: @escaping (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) {
        self.url = url ?? FinnDataMigration.directory(in:
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
            .appending(path: "sessions.json")
        self.removeItem = removeItem
    }

    func load() throws -> [WorkoutSessionSummary] {
        try protectExistingHistory()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        do {
            let sessions = try JSONDecoder().decode([WorkoutSessionSummary].self, from: data)
            guard
                Set(sessions.map(\.id)).count == sessions.count,
                sessions.allSatisfy(Self.isValid) else {
                throw SessionStoreError.corrupted
            }
            return sessions
        } catch {
            throw SessionStoreError.corrupted
        }
    }

    func save(_ session: WorkoutSessionSummary) throws {
        guard Self.isValid(session) else {
            throw SessionStoreError.invalidSession
        }
        var sessions = try load()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        try write(sessions)
    }

    func delete(id: UUID) throws {
        let remaining = try load().filter { $0.id != id }
        try write(remaining)
    }

    func deleteAll() throws {
        let directory = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        let backups = contents.filter { file in
            file.lastPathComponent.hasPrefix("sessions-corrupt-") &&
                file.lastPathComponent.hasSuffix(".json")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for backup in backups {
            try removeItem(backup)
        }
        if let primary = contents.first(where: { $0.lastPathComponent == url.lastPathComponent }) {
            try removeItem(primary)
        }
    }

    /// Moves damaged data aside before starting an empty history. The caller must request this action.
    func recoverCorruptStore() throws -> URL {
        do {
            _ = try load()
            throw SessionStoreError.notCorrupted
        } catch SessionStoreError.corrupted {
            let backup = url.deletingLastPathComponent()
                .appending(path: "sessions-corrupt-\(UUID().uuidString).json")
            try FileManager.default.moveItem(at: url, to: backup)
            return backup
        }
    }

    private func write(_ sessions: [WorkoutSessionSummary]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(sessions)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try (url as NSURL).setResourceValue(
            URLFileProtection.complete,
            forKey: .fileProtectionKey
        )
    }

    /// JSON can decode successfully and still contain impossible measurements or duplicate IDs.
    /// Keep damaged history intact for the existing recovery flow instead of feeding it to charts,
    /// comparisons or Apple Health. Failed writes must leave the last good save untouched.
    private static func isValid(_ session: WorkoutSessionSummary) -> Bool {
        guard
            session.startedAt.timeIntervalSinceReferenceDate.isFinite,
            Set(session.sets.map(\.id)).count == session.sets.count else {
            return false
        }
        return session.sets.allSatisfy { set in
            guard
                set.sessionID == session.id, set.capturedAt.timeIntervalSinceReferenceDate.isFinite,
                set.analysis.confidence.isFinite,
                (0 ... 1).contains(set.analysis.confidence) else {
                return false
            }
            var previousEnd = 0.0
            for (index, rep) in set.analysis.reps.enumerated() {
                guard
                    rep.isValid, rep.number == index + 1, rep.startTime >= previousEnd,
                    rep.endTime <= 600, rep.relativeRange <= 360,
                    abs(rep.postureValue ?? 0) <= 360 else {
                    return false
                }
                previousEnd = rep.endTime
            }
            let measurements = set.formMeasurements ?? []
            guard
                Set(measurements.map(\.check)).count == measurements.count,
                measurements.allSatisfy({
                    $0.check.exercise == set.exercise && $0.judged > 0
                        && $0.judged <= set.analysis.reps.count
                        && $0.faulty >= 0 && $0.faulty <= $0.judged
                        && $0.typical.isFinite && abs($0.typical) <= 1_000
                }) else {
                return false
            }
            if let cue = set.cue {
                let knownNumbers = Set(set.analysis.reps.map(\.number))
                guard
                    cue.repNumbers.allSatisfy(knownNumbers.contains),
                    cue.earlierMedian.isFinite, cue.laterMedian.isFinite,
                    abs(cue.earlierMedian) <= 1_000, abs(cue.laterMedian) <= 1_000 else {
                    return false
                }
            }
            return true
        }
    }

    private func protectExistingHistory() throws {
        let directory = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileProtectionKey]
        )
        for file in files {
            let name = file.lastPathComponent
            guard
                name == url.lastPathComponent ||
                (name.hasPrefix("sessions-corrupt-") && name.hasSuffix(".json")) else {
                continue
            }
            if try file.resourceValues(forKeys: [.fileProtectionKey]).fileProtection != .complete {
                try (file as NSURL).setResourceValue(
                    URLFileProtection.complete,
                    forKey: .fileProtectionKey
                )
            }
        }
    }
}
