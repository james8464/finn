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

    /// Opens the primary tabs or the two pages in the first screen's More menu.
    @MainActor
    func openFromHome(_ page: String) {
        let tabIdentifier: String?
        switch page {
        case "History", "Stats": tabIdentifier = "chart.xyaxis.line"
        case "Coach": tabIdentifier = "bubble.left.and.text.bubble.right"
        case "Awards": tabIdentifier = "rosette"
        default: tabIdentifier = nil
        }
        if let tabIdentifier {
            let tab = tabBars.buttons[tabIdentifier]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "The \(page) tab is missing")
            tab.tap()
            return
        }
        let more = buttons["home.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "The first screen's More button is missing")
        more.tap()
        let item = buttons[page].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "\(page) is missing from the More sheet")
        item.tap()
    }
}
