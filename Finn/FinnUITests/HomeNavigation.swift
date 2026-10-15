import XCTest

extension XCUIApplication {
    /// a fresh simulator shows the welcome screens first; tests that want the app itself skip them
    @MainActor
    func skipOnboardingIfShown() {
        let skip = buttons["onboarding.finish"]
        guard skip.waitForExistence(timeout: 2) else { return }
        skip.tap()
        XCTAssertTrue(buttons["tab.home"].waitForExistence(timeout: 8))
    }

    /// workout setup: the Workout tab, then Launch workout
    @MainActor
    func openWorkoutTab() {
        skipOnboardingIfShown()
        selectTab("Workout")
        launchWorkoutIfNeeded()
    }

    /// opens the selection step from the Workout tab's root; nothing when it is already open
    @MainActor
    func launchWorkoutIfNeeded() {
        let launch = buttons["workout.launch"]
        guard !buttons["home.start"].waitForExistence(timeout: 1), launch.waitForExistence(timeout: 5) else { return }
        launch.tap()
        XCTAssertTrue(buttons["home.start"].waitForExistence(timeout: 5), "Launch workout did not open setup")
    }

    /// back from workout setup to the Workout tab's root, where the More menu is
    @MainActor
    func returnToWorkoutRoot() {
        guard !buttons["home.more"].waitForExistence(timeout: 1) else { return }
        let back = navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
    }

    @MainActor
    func selectTab(_ title: String) {
        let ids = ["Home": "home", "Progress": "progress", "Progrès": "progress", "Coach": "coach",
                   "Workout": "workout", "Séance": "workout"]
        let tab = buttons["tab.\(ids[title] ?? title.lowercased())"]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab: \(title)")
        tab.tap()
    }

    /// opens History, Options or Privacy from the More menu of the first screen
    @MainActor
    func openFromHome(_ page: String) {
        returnToWorkoutRoot()
        let more = buttons["home.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "The first screen's More menu is missing")
        more.tap()
        let item = buttons[page].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "\(page) is missing from the More menu")
        item.tap()
    }
}
