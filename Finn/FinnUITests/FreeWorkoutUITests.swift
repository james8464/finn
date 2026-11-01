import XCTest

/// Without Finn Coach+, one free workout every two weeks: once it is used, Start shows the plan
/// offer with the date of the next one, and the cross leaves without starting anything
final class FreeWorkoutUITests: XCTestCase {
    @MainActor
    func testAUsedFreeWorkoutShowsThePlanOffer() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-free-limit", "-finn-ui-free-used",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        app.openWorkoutTab()
        app.buttons["home.start"].tap()

        XCTAssertTrue(app.staticTexts["You've used your free workout."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Your next free workout: '"))
            .firstMatch.exists)
        app.buttons["plan.skip"].tap()
        XCTAssertTrue(app.buttons["plan.skip"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
    }

    /// with the free workout still there, Start opens the camera as before
    @MainActor
    func testAFreeWorkoutStarts() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-free-limit"]
        app.launch()
        app.openWorkoutTab()
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["You've used your free workout."].exists)
    }
}
