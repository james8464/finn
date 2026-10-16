import Foundation

nonisolated enum SessionStoreError: Error, Equatable {
    case corrupted
    case notCorrupted
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
    static func directory(in support: URL, fileManager: FileManager = .default) -> URL {
        let current = support.appending(path: "Finn", directoryHint: .isDirectory)
        let previous = support.appending(path: "Plumb", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: previous.path) else { return current }
        do {
            if !fileManager.fileExists(atPath: current.path) {
                try fileManager.moveItem(at: previous, to: current)
            } else {
                for item in try fileManager.contentsOfDirectory(at: previous, includingPropertiesForKeys: nil) {
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

    init(url: URL? = nil,
         removeItem: @escaping (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.url = url ?? FinnDataMigration.directory(in:
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
            .appending(path: "sessions.json")
        self.removeItem = removeItem
    }

    func load() throws -> [WorkoutSessionSummary] {
        try protectExistingHistory()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        do { return try JSONDecoder().decode([WorkoutSessionSummary].self, from: data) }
        catch { throw SessionStoreError.corrupted }
    }

    func save(_ session: WorkoutSessionSummary) throws {
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
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let contents = try FileManager.default.contentsOfDirectory(at: directory,
                                                                   includingPropertiesForKeys: nil)
        let backups = contents.filter { file in
            file.lastPathComponent.hasPrefix("sessions-corrupt-") &&
                file.lastPathComponent.hasSuffix(".json")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for backup in backups { try removeItem(backup) }
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
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(sessions)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try (url as NSURL).setResourceValue(URLFileProtection.complete,
                                            forKey: .fileProtectionKey)
    }

    private func protectExistingHistory() throws {
        let directory = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: directory,
                                                                 includingPropertiesForKeys: [.fileProtectionKey])
        for file in files {
            let name = file.lastPathComponent
            guard name == url.lastPathComponent ||
                    (name.hasPrefix("sessions-corrupt-") && name.hasSuffix(".json")) else { continue }
            if try file.resourceValues(forKeys: [.fileProtectionKey]).fileProtection != .complete {
                try (file as NSURL).setResourceValue(URLFileProtection.complete,
                                                    forKey: .fileProtectionKey)
            }
        }
    }
}
