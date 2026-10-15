import XCTest

final class DashboardUITests: XCTestCase {
    @MainActor
    func testAllDashboardDestinationsAndTabs() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["tab.home"].isSelected)
        XCTAssertFalse(app.staticTexts["42:18"].exists)
        XCTAssertFalse(app.buttons["home.plus"].exists)
        XCTAssertFalse(app.staticTexts["Not made yet"].exists)

        app.buttons["tab.coach"].tap()
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tab.coach"].isSelected)
        app.buttons["tab.posture"].tap()
        XCTAssertTrue(app.navigationBars["Posture"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tab.posture"].isSelected)
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Squat"].exists)
        app.buttons["tab.home"].tap()

        for card in ["lastSession", "posture", "weights", "sessions", "awards"] {
            let button = app.buttons["home.\(card)"]
            if !button.isHittable { app.swipeUp() }
            button.tap()
            switch card {
            case "lastSession": XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 3))
            case "sessions": XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
            case "posture": XCTAssertTrue(app.navigationBars["Posture"].waitForExistence(timeout: 3))
            case "weights": XCTAssertTrue(app.navigationBars["Best set"].waitForExistence(timeout: 3))
            default: XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 3))
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.swipeDown()
        app.buttons["home.account"].tap()
        XCTAssertTrue(app.navigationBars["Account settings"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        app.buttons["tab.home"].tap()
        XCTAssertFalse(app.staticTexts["No workouts yet"].exists)
        app.buttons["home.lastSession"].tap()
        XCTAssertTrue(app.navigationBars["Session"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargeTextKeepsNavigationUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.account"].isHittable)
        app.buttons["tab.coach"].tap()
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.buttons["home.lastSession"].exists)
    }
}
