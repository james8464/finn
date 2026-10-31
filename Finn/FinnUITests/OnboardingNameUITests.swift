import XCTest

/// a first name keeps every letter typed: accents, ç, apostrophes, hyphens and spaces
final class OnboardingNameUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNameKeepsAccentsAndPunctuation() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-onboarding"]
        app.launch()
        let welcome = app.buttons["onboarding.welcome.continue"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 8))
        welcome.tap()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        next.tap()
        Thread.sleep(forTimeInterval: 0.6)
        next.tap()
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        let typed = "Zoé-Anne Ç'éèêëïô"
        app.typeText(typed)
        XCTAssertEqual(name.value as? String, typed)
        XCTAssertTrue(next.isEnabled)
    }
}
