import XCTest

extension XCUIApplication {
    /// A fresh simulator shows the welcome screens first; tests that want the app itself skip them.
    @MainActor
    func skipOnboardingIfShown() {
        let skip = buttons["onboarding.finish"]
        guard skip.waitForExistence(timeout: 2) else { return }
        skip.tap()
        XCTAssertTrue(tabBars.firstMatch.waitForExistence(timeout: 8))
    }

    @MainActor
    func openWorkoutTab() {
        skipOnboardingIfShown()
        selectTab("Workout")
    }

    @MainActor
    func selectTab(_ title: String) {
        let tab = tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing native tab: \(title)")
        tab.tap()
    }

    /// Opens History, Options or Privacy from the More menu of the first screen.
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
