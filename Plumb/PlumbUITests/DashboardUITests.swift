import XCTest

final class DashboardUITests: XCTestCase {
    @MainActor
    func testAllDashboardDestinationsAndTabs() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Summary"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Summary"].isSelected)
        XCTAssertFalse(app.staticTexts["42:18"].exists)
        XCTAssertFalse(app.staticTexts["Not made yet"].exists)
        app.selectTab("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        app.selectTab("History")
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Squat"].exists)
        app.selectTab("Summary")
        app.buttons["home.awards"].tap()
        XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 3))
        app.selectTab("Workout")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        app.selectTab("Summary")
        XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["home.account"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        app.buttons["Options"].tap()
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Privacy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSavedWorkoutAppearsOnDashboard() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        app.openWorkoutTab()
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
        XCTAssertTrue(app.tabBars.buttons["Summary"].waitForExistence(timeout: 5))
        app.selectTab("Summary")
        XCTAssertFalse(app.staticTexts["No workouts yet"].exists)
        app.buttons["home.lastSession"].tap()
        XCTAssertTrue(app.navigationBars["Session"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNestedNavigationSurvivesCameraPresentation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        app.buttons["home.account"].tap()
        app.buttons["Options"].tap()
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 3))
        app.openWorkoutTab()
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.selectTab("Summary")
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 3),
                      "Returning from the camera must preserve nested tab navigation")
    }

    @MainActor
    func testLargeTextKeepsNavigationUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.account"].isHittable)
        app.selectTab("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        app.selectTab("Summary")
        XCTAssertTrue(app.buttons["home.lastSession"].exists)
    }
}
