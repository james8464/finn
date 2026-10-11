import XCTest

final class WorkoutFlowUITests: XCTestCase {
    @MainActor
    func testDemoSetShowsMeasuredResultAndRetake() {
        let app = XCUIApplication()
        app.launchArguments.append("-plumb-ui-demo")
        app.launch()

        XCTAssertTrue(app.staticTexts["DEMO INPUT"].exists)
        app.buttons["Set up camera"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 5))
        app.buttons["Start set"].tap()
        XCTAssertTrue(app.buttons["Stop set"].waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        app.buttons["Stop set"].tap()

        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Measured reps"].exists)
        XCTAssertTrue(app.staticTexts["Your range became shorter in the last two reps."].exists)
        app.buttons["Try another set"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 5))
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
        stop.tap()
    }
}
