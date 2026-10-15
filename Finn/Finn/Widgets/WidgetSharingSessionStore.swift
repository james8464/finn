import Foundation
import WidgetKit

nonisolated extension LastSetSnapshot {
    /// the most recent set in `sessions`, for the widget. Nil when no set is saved.
    static func latest(in sessions: [WorkoutSessionSummary]) -> LastSetSnapshot? {
        guard let set = sessions.flatMap(\.sets).max(by: { $0.capturedAt < $1.capturedAt }) else {
            return nil
        }
        return LastSetSnapshot(exerciseName: set.exercise.definition.copy.name,
                               exerciseKey: set.exercise.rawValue,
                               reps: set.analysis.reps.count,
                               capturedAt: set.capturedAt,
                               partlyVisible: set.partlyVisible == true)
    }
}

/// the app's session store, with the widget kept in step: after every write to the local history,
/// the latest saved set goes to the App Group and the widget reloads. The widget therefore never
/// shows a set the history does not have. Demo and recorded input use their own store and never
/// pass through here
nonisolated struct WidgetSharingSessionStore: SessionStoring {
    private let base: any SessionStoring
    private let shared: SharedSetStore?
    private let widgetsChanged: @Sendable () -> Void

    init(base: any SessionStoring, shared: SharedSetStore? = SharedSetStore.appGroup,
         widgetsChanged: @escaping @Sendable () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.base = base
        self.shared = shared
        self.widgetsChanged = widgetsChanged
    }

    func load() throws -> [WorkoutSessionSummary] { try base.load() }

    func save(_ session: WorkoutSessionSummary) throws {
        try base.save(session)
        publish()
    }

    func delete(id: UUID) throws {
        try base.delete(id: id)
        publish()
    }

    func deleteAll() throws {
        try base.deleteAll()
        publish()
    }

    func recoverCorruptStore() throws -> URL {
        let backup = try base.recoverCorruptStore()
        publish()
        return backup
    }

    /// rereads the history after a write, so the widget shows what is saved rather than what was
    /// about to be. A history that cannot be read leaves the widget empty rather than stale.
    private func publish() {
        guard let shared else { return }
        let snapshot = (try? base.load()).flatMap { LastSetSnapshot.latest(in: $0) }
        guard snapshot != shared.read() else { return }
        shared.write(snapshot)
        widgetsChanged()
    }
}
