import XCTest

extension XCUIApplication {
    /// Native lists load rows on demand; scroll until the requested control can be used.
    @MainActor
    func reveal(_ element: XCUIElement, swipes: Int = 12) {
        for _ in 0 ..< swipes {
            if element.exists && element.isHittable {
                return
            }
            swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Control could not be reached: \(element)")
    }

    /// a fresh simulator shows the welcome screens first; tests that want the app itself skip them
    @MainActor
    func skipOnboardingIfShown() {
        passWelcomeIfShown()
        guard buttons["onboarding.skip"].waitForExistence(timeout: 2) else {
            return
        }
        skipRemainingOnboarding()
    }

    /// the onboarding can't be left early: from any step, Skip each screen, Continue on the summary,
    /// Skip on the plan offer, then a tap above the free workout it offers closes that sheet
    @MainActor
    func skipRemainingOnboarding() {
        let skip = buttons["onboarding.skip"]
        let summary = buttons["summary.continue"]
        for _ in 0 ..< 12 where !summary.exists {
            if skip.exists && skip.isHittable {
                skip.tap()
            }
            _ = summary.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(summary.waitForExistence(timeout: 12), "The plan summary did not appear")
        summary.tap()
        let skipPlan = buttons["plan.skip"]
        XCTAssertTrue(skipPlan.waitForExistence(timeout: 5))
        skipPlan.tap()
        let offer = buttons["freeWorkout.accept"]
        if offer.waitForExistence(timeout: 5) {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
            XCTAssertTrue(offer.waitForNonExistence(timeout: 5), "The free workout offer did not close")
        }
        XCTAssertTrue(buttons["tab.home"].waitForExistence(timeout: 8))
    }

    /// the onboarding opens on the welcome; its Continue leads to the first step
    @MainActor
    func passWelcomeIfShown() {
        let welcome = buttons["onboarding.welcome.continue"]
        guard welcome.waitForExistence(timeout: 2) else {
            return
        }
        welcome.tap()
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
        guard
            !buttons["home.start"].waitForExistence(timeout: 1),
            launch.waitForExistence(timeout: 5) else {
            return
        }
        launch.tap()
        XCTAssertTrue(buttons["home.start"].waitForExistence(timeout: 5), "Launch workout did not open setup")
    }

    /// back from workout setup to the Workout tab's root, where the More menu is
    @MainActor
    func returnToWorkoutRoot() {
        guard !buttons["home.more"].waitForExistence(timeout: 1) else {
            return
        }
        let back = navigationBars.buttons.element(boundBy: 0)
        if back.exists {
            back.tap()
        }
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
        XCTAssertTrue(navigationBars[page].waitForExistence(timeout: 5))
    }
}
