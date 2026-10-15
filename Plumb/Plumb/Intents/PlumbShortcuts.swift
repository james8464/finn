import AppIntents

/// the phrases Siri, Spotlight and the Shortcuts app offer as soon as Plumb is installed, with no
/// setup. `\(.applicationName)` is "Plumb"; `\(\.$exercise)` takes any exercise name or synonym.
struct PlumbShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSetIntent(),
            phrases: [
                "Start a \(\.$exercise) set in \(.applicationName)",
                "Start \(\.$exercise) in \(.applicationName)",
                "Start a set in \(.applicationName)",
                "Start a set with \(.applicationName)"
            ],
            shortTitle: "Start a Set",
            systemImageName: "figure.strengthtraining.functional"
        )
        AppShortcut(
            intent: LastSetIntent(),
            phrases: [
                "How did my last set go in \(.applicationName)",
                "How was my last set in \(.applicationName)",
                "What was my last set in \(.applicationName)",
                "\(.applicationName) last set"
            ],
            shortTitle: "Last Set",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: ShowHistoryIntent(),
            phrases: [
                "Show my history in \(.applicationName)",
                "Show my \(.applicationName) history",
                "Open \(.applicationName) history"
            ],
            shortTitle: "History",
            systemImageName: "list.bullet.rectangle"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .navy
}
