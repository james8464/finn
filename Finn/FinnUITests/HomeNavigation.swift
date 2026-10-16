import XCTest

extension XCUIApplication {
    /// a fresh simulator shows the welcome screens first; tests that want the app itself skip them
    @MainActor
    func skipOnboardingIfShown() {
        passWelcomeIfShown()
        let skip = buttons["onboarding.finish"]
        guard skip.waitForExistence(timeout: 2) else { return }
        skip.tap()
        XCTAssertTrue(buttons["tab.home"].waitForExistence(timeout: 8))
    }

    /// the onboarding opens on the welcome; its Continue leads to the first step
    @MainActor
    func passWelcomeIfShown() {
        let welcome = buttons["onboarding.welcome.continue"]
        guard welcome.waitForExistence(timeout: 2) else { return }
        welcome.tap()
    }

    @MainActor
    func openWorkoutTab() {
        skipOnboardingIfShown()
        selectTab("Workout")
    }

    @MainActor
    func selectTab(_ title: String) {
        let ids = ["Home": "home", "Posture": "posture", "Coach": "coach", "Workout": "workout", "Séance": "workout"]
        let tab = buttons["tab.\(ids[title] ?? title.lowercased())"]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab: \(title)")
        tab.tap()
    }

    /// opens History, Options or Privacy from the More menu of the first screen
    @MainActor
    func openFromHome(_ page: String) {
        let more = buttons["home.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "The first screen's More menu is missing")
        more.tap()
        let item = buttons[page].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "\(page) is missing from the More menu")
        item.tap()
    }
}
