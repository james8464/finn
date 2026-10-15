import XCTest

final class WelcomeFlowUITests: XCTestCase {
    @MainActor
    func testWorkoutNavigationHelperCompletesWelcome() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-plumb-ui-onboarding"]
        app.launch()
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.continue"].exists)
    }

    @MainActor
    func testWelcomeDemoPlansAndReplayLeaveHistoryEmpty() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let suite = "WelcomeFlow-\(UUID().uuidString)"
        app.launchArguments = ["-plumb-ui-demo", "-plumb-ui-preferences-suite", suite]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Find your line."].firstMatch.exists)
        next.tap()
        XCTAssertTrue(app.otherElements["demo.capture"].waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(app.otherElements["demo.advice"].waitForExistence(timeout: 5))
        app.buttons["onboarding.back"].tap()
        XCTAssertTrue(app.otherElements["demo.capture"].waitForExistence(timeout: 5))
        next.tap()
        next.tap()
        XCTAssertTrue(app.buttons["paywall.free"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.free"].isSelected)
        next.tap()
        XCTAssertTrue(app.buttons["home.tryPlumb"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.home"].isSelected)
        XCTAssertTrue(app.staticTexts["No workouts yet"].exists)
        app.buttons["home.tryPlumb"].tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.workout"].isSelected)
        app.buttons["tab.home"].tap()

        app.buttons["home.watchDemo"].tap()
        XCTAssertTrue(app.buttons["demo.close"].waitForExistence(timeout: 5))
        app.buttons["demo.close"].tap()
        XCTAssertTrue(app.buttons["home.tryPlumb"].waitForExistence(timeout: 5))
        app.buttons["home.watchDemo"].tap()
        app.buttons["demo.continue"].tap()
        XCTAssertTrue(app.otherElements["demo.advice"].waitForExistence(timeout: 5))
        app.buttons["demo.replay"].tap()
        XCTAssertTrue(app.otherElements["demo.capture"].waitForExistence(timeout: 5))
        app.buttons["demo.continue"].tap()
        app.buttons["demo.continue"].tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.workout"].isSelected)
        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.staticTexts["No workouts yet"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.tryPlumb"].waitForExistence(timeout: 8))
        XCTAssertFalse(next.exists, "Completing the tour persists across launches")
    }

    @MainActor
    func testMonthlyAndAnnualPreviewChoicesAndSkip() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-plumb-ui-onboarding"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 8))
        app.buttons["onboarding.skip"].tap()
        let monthly = app.buttons["paywall.monthly"]
        let annual = app.buttons["paywall.annual"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        if !monthly.isHittable { app.swipeUp() }
        monthly.tap()
        XCTAssertTrue(monthly.isSelected)
        XCTAssertFalse(annual.isSelected)
        XCTAssertTrue(app.staticTexts["€9.99"].exists)
        annual.tap()
        XCTAssertTrue(annual.isSelected)
        XCTAssertFalse(monthly.isSelected)
        XCTAssertTrue(app.staticTexts["€99"].exists)
        XCTAssertTrue(app.staticTexts["€8.25 / month · save 17%"].exists)
        XCTAssertTrue(app.staticTexts["Plan preview · no payment today"].exists)
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["home.tryPlumb"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargeTextCanChooseFreeAndReachHome() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-plumb-ui-onboarding",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertTrue(next.isHittable)
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(next.isHittable)
        next.tap()
        XCTAssertTrue(app.buttons["home.tryPlumb"].waitForExistence(timeout: 5))
    }
}
