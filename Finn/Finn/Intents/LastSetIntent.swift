import AppIntents
import SwiftUI

/// "How did my last set go in Finn": answers from the saved history without opening the app. Siri
/// reads one sentence and shows a card; both come from `LastSetReport`, never from a guess
struct LastSetIntent: AppIntent {
    static let title: LocalizedStringResource = "How Did My Last Set Go"
    static let description = IntentDescription(
        "Tells you your last measured set: exercise, reps, when, and the observation Finn recorded.",
        categoryName: "Sets")
    static let openAppWhenRun = false

    func perform() async throws -> some ProvidesDialog & ShowsSnippetView {
        let (dialog, content) = Self.answer(from: LocalSessionStore())
        return .result(dialog: IntentDialog("\(dialog)"), view: LastSetSnippet(content: content))
    }

    /// the spoken sentence and the card content for what the store holds. Pure apart from reading
    /// the store, so tests cover the empty, unreadable and recorded cases
    nonisolated static func answer(from store: any SessionStoring,
                                   now: Date = Date()) -> (String, LastSetSnippet.Content) {
        let sessions: [WorkoutSessionSummary]
        do { sessions = try store.load() } catch { return (LastSetReport.unavailable, .unavailable) }
        guard let report = LastSetReport.latest(in: sessions) else {
            return (LastSetReport.nothingYet, .nothingYet)
        }
        return (report.spoken(now: now), .report(report))
    }
}
