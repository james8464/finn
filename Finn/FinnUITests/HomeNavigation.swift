import XCTest

extension XCUIApplication {
    /// Native lists load rows on demand; scroll until the requested control can be used.
    @MainActor
    func reveal(_ element: XCUIElement, swipes: Int = 12) {
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return }
            swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Control could not be reached: \(element)")
    }

    /// A fresh simulator shows the welcome screens first; tests that want the app itself skip them.
    @MainActor
    func skipOnboardingIfShown() {
        let skip = buttons["onboarding.finish"]
        guard skip.waitForExistence(timeout: 2) else { return }
        skip.tap()
        XCTAssertTrue(buttons["tab.home"].waitForExistence(timeout: 8))
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

    /// Opens History, Options or Privacy from the More menu of the first screen.
    @MainActor
    func openFromHome(_ page: String) {
        let more = buttons["home.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "The first screen's More menu is missing")
        more.tap()
        let item = buttons[page].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "\(page) is missing from the More menu")
        item.tap()
        XCTAssertTrue(navigationBars[page].waitForExistence(timeout: 5))
    }
}
