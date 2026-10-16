import XCTest

final class CameraAngleUITests: XCTestCase {
    /// the Debug demo feed attaches a synthetic 75° profile deviation, standing in for a
    /// front-facing person. Counts remain available while posture advice is withheld.
    @MainActor
    func testFrontViewSetKeepsCountWithoutSideViewPostureAdvice() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-finn-ui-demo", "-finn-ui-demo-front-view"]
        app.launch()
        app.openWorkoutTab()
        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
        let limits = app.buttons["result.measurementLimits"]
        app.reveal(limits)
        limits.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "counted your reps without posture advice")).firstMatch.exists)
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription, .dynamicType, .hitRegion, .textClipped, .trait,
        ]) { issue in
            print("Front-view result audit: \(issue.compactDescription) · \(issue.element?.debugDescription ?? "no element")")
            return false
        }

        app.buttons["Done"].tap()
        app.openFromHome("Options")
        let toggle = app.switches["options.checkCameraAngle"]
        app.reveal(toggle)
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription, .dynamicType, .hitRegion, .textClipped, .trait,
        ]) { issue in
            print("Camera-angle options audit: \(issue.compactDescription) · \(issue.element?.debugDescription ?? "no element")")
            return false
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // Options opens from the Workout tab's root: setup is one Launch workout away
        app.launchWorkoutIfNeeded()

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
        app.launchArguments += ["-finn-ui-demo", "-finn-ui-demo-front-view", "-finn-validation"]
        app.launch()
        app.openWorkoutTab()
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

    /// a push-up filmed from the front is measured, not refused: the framing screen and the
    /// result never ask the person to turn sideways
    @MainActor
    func testFrontViewPushUpIsMeasuredNotRefused() {
        let app = XCUIApplication()
        app.launchArguments += ["-finn-ui-demo", "-finn-ui-demo-front-view"]
        app.launch()
        app.openWorkoutTab()
        app.buttons["Push-up"].tap()
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
