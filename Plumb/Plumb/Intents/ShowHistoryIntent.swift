import AppIntents

/// "Show my history in Plumb": opens the app on the History screen.
struct ShowHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show My History"
    static let description = IntentDescription("Opens Plumb on your saved sessions.", categoryName: "Sets")
    static let openAppWhenRun = true

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run { SiriLaunchRequests.shared.pending = .showHistory }
        return .result()
    }
}
