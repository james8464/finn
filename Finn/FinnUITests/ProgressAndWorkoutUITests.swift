import XCTest

final class ProgressAndWorkoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        return app
    }

    /// Home's Posture card lands on Posture even after the person left Progress on Strength
    @MainActor
    func testPostureCardAlwaysOpensThePostureSection() {
        let app = launch()
        app.selectTab("Progress")
        let section = app.segmentedControls["progress.section"]
        XCTAssertTrue(section.waitForExistence(timeout: 3))
        section.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["strength.card"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No workouts yet"].exists)
        app.selectTab("Home")
        app.buttons["home.posture"].tap()
        XCTAssertTrue(app.buttons["tab.progress"].isSelected)
        XCTAssertTrue(section.buttons.element(boundBy: 0).isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["posture.guide"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["posture.illustration"].exists)
        XCTAssertTrue(app.staticTexts["No photos yet"].exists || app.descendants(matching: .any)["posture.moments"].exists)
    }

    /// the Workout tab shows the next workout and history; Launch workout opens setup, and camera
    /// privacy from setup comes back to setup
    @MainActor
    func testLaunchWorkoutOpensSetupBeforeTheCamera() {
        let app = launch()
        app.selectTab("Workout")
        XCTAssertTrue(app.descendants(matching: .any)["workout.next"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Previous workouts"].exists)
        XCTAssertFalse(app.buttons["home.start"].exists)
        let launch = app.buttons["workout.launch"]
        XCTAssertTrue(launch.isHittable)
        XCTAssertLessThanOrEqual(launch.frame.maxY, app.buttons["tab.home"].frame.minY)
        launch.tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        app.buttons["home.privacy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["workout.launch"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.more"].exists)
    }

    /// at the largest text size the next-workout card grows past square and Launch workout stays
    /// reachable above the tab bar
    @MainActor
    func testWorkoutAndProgressAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.skipOnboardingIfShown()
        app.selectTab("Workout")
        XCTAssertTrue(app.descendants(matching: .any)["workout.next"].waitForExistence(timeout: 5))
        let launch = app.buttons["workout.launch"]
        XCTAssertTrue(launch.isHittable)
        XCTAssertLessThanOrEqual(launch.frame.maxY, app.buttons["tab.home"].frame.minY)
        attach(app, "workout-largest-text")
        app.selectTab("Progress")
        XCTAssertTrue(app.descendants(matching: .any)["posture.guide"].waitForExistence(timeout: 5))
        attach(app, "progress-largest-text")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
