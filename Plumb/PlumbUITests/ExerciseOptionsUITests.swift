import XCTest

final class ExerciseOptionsUITests: XCTestCase {
    @MainActor
    func testOptionsExplainAngleRulesAndTurnThemOnByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-plumb-ui-demo")
        app.launch()
        app.buttons["Options"].tap()
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 5))
        // XCTest refuses identifier queries longer than 128 characters, so match the start.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "After each set, Plumb guesses the exercise from your joint angles")).firstMatch.exists)
        let toggle = app.switches["options.recognizeExercise"]
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertFalse(app.switches["options.useTrainedModel"].exists)
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription, .dynamicType, .hitRegion, .textClipped, .trait,
        ])
    }

    @MainActor
    func testExercisePickerChangesSetupGuidance() {
        let app = XCUIApplication()
        app.launchArguments.append("-plumb-ui-demo")
        app.launch()
        let picker = app.buttons["setup.exercise"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.label, "Exercise: Squat")
        picker.tap()
        app.buttons["Push-up"].tap()
        XCTAssertEqual(picker.label, "Exercise: Push-up")
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "On the floor or a low step")).firstMatch.exists)
        app.buttons["Set up camera"].tap()
        XCTAssertTrue(app.staticTexts["Checking arm visibility"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTrainedModelSwitchUsesDemoClassifierAndReportsIt() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-plumb-ui-demo", "-plumb-ui-demo-recognition"]
        app.launch()
        app.buttons["Options"].tap()
        XCTAssertEqual(app.switches["options.recognizeExercise"].value as? String, "1")
        let toggle = app.switches["options.useTrainedModel"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        try app.performAccessibilityAudit(for: [
            .sufficientElementDescription, .dynamicType, .hitRegion, .textClipped, .trait,
        ])
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["After the set, Plumb also checks which exercise you did. If it isn’t sure, it keeps your choice."].waitForExistence(timeout: 5))

        app.buttons["Set up camera"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recognized as Squat on this iPhone."].exists)
    }
}
