import XCTest

extension XCUIApplication {
    /// A fresh simulator shows the welcome screens first; tests that want the app itself skip them.
    @MainActor
    func skipOnboardingIfShown() {
        let skip = buttons["onboarding.skip"]
        guard skip.waitForExistence(timeout: 2) else { return }
        for _ in 0..<6 where skip.exists {
            skip.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// The first screen: one title, one Start button.
    @MainActor
    func openHome() {
        skipOnboardingIfShown()
        XCTAssertTrue(buttons["home.start"].waitForExistence(timeout: 5), "The first screen is missing")
    }

    /// Picks an exercise from the menu behind the first screen's title.
    @MainActor
    func chooseExercise(_ name: String) {
        let title = buttons["home.exercise"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "The exercise title is missing")
        title.tap()
        let item = buttons[name].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "\(name) is missing from the exercise menu")
        item.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Opens a page from the first screen: Stats (History), Coach and Awards are tabs; Options and
    /// Privacy sit behind the icon at the top right.
    @MainActor
    func openFromHome(_ page: String) {
        let tabName = ["History": "Stats", "Stats": "Stats", "Coach": "Coach", "Awards": "Stats"][page]
        if let tabName {
            let tab = tabBars.buttons[tabName]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "The \(tabName) tab is missing")
            tab.tap()
            if page == "Awards" {
                let link = buttons["stats.awards"]
                XCTAssertTrue(link.waitForExistence(timeout: 5), "The Awards link is missing from Stats")
                link.tap()
            }
            return
        }
        let more = buttons["home.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "The first screen's More button is missing")
        more.tap()
        let item = buttons[page].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "\(page) is missing from the More menu")
        item.tap()
    }

    /// Back to the first screen after `openFromHome`.
    @MainActor
    func returnHome() {
        let workout = tabBars.buttons["Workout"]
        if workout.exists && !workout.isSelected { workout.tap() }
        if !buttons["home.start"].waitForExistence(timeout: 2) {
            navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
}
