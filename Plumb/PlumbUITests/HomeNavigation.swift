import XCTest

extension XCUIApplication {
    @MainActor
    func openWorkoutTab() {
        let tab = buttons["tab.workout"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
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
