import XCTest

/// The first screen: one title, one Start button, and every other page behind the one icon.
final class HomeUITests: XCTestCase {
    @MainActor
    func testEveryPageOpensFromTheMoreSheetAndComesBack() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        app.openHome()
        XCTAssertFalse(app.tabBars.firstMatch.exists, "The first screen has no tab bar")
        for (page, check) in [("History", "History"), ("Coach", "Coach"), ("Awards", "Awards"),
                              ("Options", "Options"), ("Privacy", "Privacy")] {
            app.openFromHome(page)
            XCTAssertTrue(app.navigationBars[check].waitForExistence(timeout: 5), page)
            if page == "Coach" { XCTAssertTrue(app.textFields["coach.field"].exists) }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5), "Back from \(page)")
        }
    }

    @MainActor
    func testTitleFollowsTheChosenExercise() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        app.openHome()
        XCTAssertTrue(app.staticTexts["Ready for squats?"].exists)
        app.chooseExercise("Push-up")
        XCTAssertTrue(app.staticTexts["Ready for push-ups?"].waitForExistence(timeout: 3))
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.staticTexts["Checking shoulder and hand visibility"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavedSetShowsOnTheFirstScreen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        app.openHome()
        app.buttons["home.start"].tap()
        let start = app.buttons["Start set"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 8))
        app.buttons["Done"].tap()
        let line = app.buttons["home.progress"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.contains("this week"), line.label)
    }

    @MainActor
    func testLargeTextKeepsTheFirstScreenUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.openHome()
        XCTAssertTrue(app.buttons["home.start"].isHittable)
        XCTAssertTrue(app.buttons["home.more"].isHittable)
        app.openFromHome("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
    }
}
