import XCTest

extension XCUIApplication {
    /// a fresh simulator shows the welcome screens first; tests that want the app itself skip them
    @MainActor
    func skipOnboardingIfShown() {
        let skip = buttons["onboarding.skip"]
        guard skip.waitForExistence(timeout: 2) else { return }
        for _ in 0..<6 where skip.exists {
            skip.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    @MainActor
    func openWorkoutTab() {
        skipOnboardingIfShown()
        let tab = buttons["tab.workout"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
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
