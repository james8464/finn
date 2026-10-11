import XCTest

final class WorkoutFlowUITests: XCTestCase {
    @MainActor
    func testPrivacySummaryIsReachableFromSetup() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Privacy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].exists)
        XCTAssertTrue(app.staticTexts["Video is processed on this iPhone and never saved."].exists)
        XCTAssertTrue(app.staticTexts["Saved summaries may be included in your device backup."].exists)
        XCTAssertTrue(app.staticTexts["Delete saved sessions in History."].exists)
    }

    @MainActor
    func testDemoSetShowsMeasuredResultAndRetake() {
        let app = XCUIApplication()
        app.launchArguments.append("-plumb-ui-demo")
        app.launch()

        XCTAssertTrue(app.staticTexts["DEMO INPUT"].exists)
        capture(app, name: "Setup")
        app.buttons["Set up camera"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 5))
        app.buttons["Start set"].tap()
        XCTAssertTrue(app.buttons["Stop set"].waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        app.buttons["Stop set"].tap()

        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["validation.stopToResult"].exists)
        capture(app, name: "First result")
        XCTAssertTrue(app.staticTexts["Measured reps"].exists)
        XCTAssertTrue(app.staticTexts["Your range became shorter in the last two reps."].exists)
        app.buttons["Try this next set"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 5))
        app.buttons["Start set"].tap()
        XCTAssertTrue(app.buttons["Stop set"].waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        app.buttons["Stop set"].tap()
        XCTAssertTrue(app.staticTexts["Compared with your previous set"].waitForExistence(timeout: 5))
        capture(app, name: "Comparison")
        app.buttons["Explain comparison"].tap()
        XCTAssertTrue(app.staticTexts["Comparison note"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let history = app.buttons["History"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        XCTAssertTrue(app.staticTexts["Saved sessions"].waitForExistence(timeout: 5))
        let delete = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Delete session from")).firstMatch
        delete.tap()
        app.buttons["Delete session"].tap()
        XCTAssertTrue(app.staticTexts["No saved sessions yet."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStopRemainsReachableWithLargeTextInDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-plumb-ui-demo",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM",
            "-UIUserInterfaceStyle", "Dark",
        ]
        app.launch()
        app.buttons["Set up camera"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        XCTAssertTrue(stop.isHittable)
        capture(app, name: "Large text dark capture")
        stop.tap()
    }

    @MainActor
    func testDismissedCueAcknowledgesFeedback() {
        let app = XCUIApplication()
        app.launchArguments.append("-plumb-ui-demo")
        app.launch()
        app.buttons["Set up camera"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        let notRelevant = app.buttons["Not relevant"]
        XCTAssertTrue(notRelevant.waitForExistence(timeout: 5))
        notRelevant.tap()
        XCTAssertTrue(app.staticTexts["Observation marked not relevant."].exists)
        XCTAssertFalse(app.staticTexts["No clear pattern to call out in this set."].exists)
    }

    @MainActor
    func testValidationLaunchShowsStopTiming() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-plumb-validation"]
        app.launch()
        app.buttons["Set up camera"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        let timing = app.staticTexts["validation.stopToResult"]
        XCTAssertTrue(timing.waitForExistence(timeout: 5))
        XCTAssertTrue(timing.label.contains("Stop to result:"))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
