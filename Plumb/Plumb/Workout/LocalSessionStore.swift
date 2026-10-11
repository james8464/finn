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

nonisolated struct LocalSessionStore: SessionStoring {
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Plumb", directoryHint: .isDirectory)
            .appending(path: "sessions.json")
    }

    func load() throws -> [WorkoutSessionSummary] {
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
        for file in contents {
            let name = file.lastPathComponent
            if name == url.lastPathComponent ||
                (name.hasPrefix("sessions-corrupt-") && name.hasSuffix(".json")) {
                try FileManager.default.removeItem(at: file)
            }
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
        try data.write(to: url, options: .atomic)
    }
}
