import XCTest

final class DashboardUITests: XCTestCase {
    @MainActor
    func testSummaryTitleCollapsesAndScrollPositionSurvivesTabSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        app.launch()
        let scroll = app.scrollViews["summary.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        let title = app.navigationBars["Home"].staticTexts["Home"]
        let expandedHeight = title.frame.height
        scroll.swipeUp()
        XCTAssertTrue(app.buttons["home.awards"].isHittable)
        XCTAssertLessThan(title.frame.height, expandedHeight, "Native title must collapse while scrolling")
        let position = app.buttons["home.awards"].frame.minY
        let collapsedHeight = title.frame.height
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "summary-scrolled-before-tab-switch"
        before.lifetime = .keepAlways
        add(before)
        app.selectTab("Workout")
        app.selectTab("Home")
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "summary-scrolled-after-tab-switch"
        after.lifetime = .keepAlways
        add(after)
        XCTAssertEqual(title.frame.height, collapsedHeight, accuracy: 3)
        XCTAssertEqual(app.buttons["home.awards"].frame.minY, position, accuracy: 3)
        scroll.swipeDown()
        scroll.swipeDown()
        XCTAssertEqual(title.frame.height, expandedHeight, accuracy: 3)
    }

    @MainActor
    func testAllDashboardDestinationsAndTabs() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["tab.home"].isSelected)
        XCTAssertFalse(app.staticTexts["42:18"].exists)
        XCTAssertFalse(app.staticTexts["Not made yet"].exists)
        app.buttons["home.sessions"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.selectTab("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        app.selectTab("Posture")
        XCTAssertTrue(app.navigationBars["Posture"].waitForExistence(timeout: 3))
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Squat"].exists)
        app.selectTab("Home")
        app.buttons["home.awards"].tap()
        XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 3))
        app.selectTab("Workout")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        app.selectTab("Home")
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
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        app.selectTab("Home")
        XCTAssertFalse(app.staticTexts["No workouts yet"].exists)
        XCTAssertTrue((app.buttons["home.sessions"].value as? String)?.contains("reps in the last 7 days") == true)
        let saved = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        saved.name = "summary-saved-workout"
        saved.lifetime = .keepAlways
        add(saved)
        let title = app.navigationBars["Home"].staticTexts["Home"]
        let expandedHeight = title.frame.height
        app.scrollViews["summary.scroll"].swipeUp()
        let collapsedHeight = title.frame.height
        XCTAssertLessThan(collapsedHeight, expandedHeight)
        let savedPosition = app.buttons["home.lastSession"].frame.minY
        app.selectTab("Workout")
        app.selectTab("Home")
        XCTAssertEqual(title.frame.height, collapsedHeight, accuracy: 3)
        XCTAssertEqual(app.buttons["home.lastSession"].frame.minY, savedPosition, accuracy: 3)
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
        app.selectTab("Home")
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
        app.selectTab("Home")
        XCTAssertTrue(app.buttons["home.awards"].exists)
    }
}
