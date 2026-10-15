import XCTest

final class CameraAngleUITests: XCTestCase {
    /// The Debug demo feed attaches a synthetic 75° profile deviation, standing in for a
    /// front-facing person. It checks the refusal path, not the accuracy of Vision 3D pose.
    @MainActor
    func testFrontViewSetIsRefusedUntilTheCheckIsSwitchedOff() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-plumb-ui-demo", "-plumb-ui-demo-front-view"]
        app.launch()
        app.openHome()
        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Couldn’t assess this set"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "This exercise needs a side view. Turn so your side faces the camera")).firstMatch.exists)
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription, .dynamicType, .hitRegion, .textClipped, .trait,
        ])

        app.buttons["Done"].tap()
        app.openFromHome("Options")
        let toggle = app.switches["options.checkCameraAngle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription, .dynamicType, .hitRegion, .textClipped, .trait,
        ])
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testValidationModeShowsTheThreeDimensionalVerdict() {
        let app = XCUIApplication()
        app.launchArguments += ["-plumb-ui-demo", "-plumb-ui-demo-front-view", "-plumb-validation"]
        app.launch()
        app.openHome()
        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        let readout = app.staticTexts["validation.viewCheck"]
        XCTAssertTrue(readout.waitForExistence(timeout: 5))
        XCTAssertTrue(readout.label.contains("75° from profile"))
        XCTAssertTrue(readout.label.contains("refused"))
    }

    /// A push-up filmed from the front is measured, not refused: the framing screen and the
    /// result never ask the person to turn sideways.
    @MainActor
    func testFrontViewPushUpIsMeasuredNotRefused() {
        let app = XCUIApplication()
        app.launchArguments += ["-plumb-ui-demo", "-plumb-ui-demo-front-view"]
        app.launch()
        app.openHome()
        app.chooseExercise("Push-up")
        app.buttons["Start a set"].tap()
        XCTAssertTrue(app.staticTexts["Checking shoulder and hand visibility"].waitForExistence(timeout: 5))
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(app.staticTexts["Turn a little: side to the camera"].exists)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "needs a side view")).firstMatch.exists)
    }
}
