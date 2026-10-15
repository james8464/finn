import XCTest

final class ExerciseOptionsUITests: XCTestCase {
    @MainActor
    func testOptionsExplainAngleRulesAndTurnThemOnByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-plumb-ui-demo")
        app.launch()
        app.openHome()
        app.openFromHome("Options")
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
        app.openHome()
        XCTAssertTrue(app.staticTexts["Ready for squats?"].exists, "Squat is the exercise ready on first launch")
        app.chooseExercise("Push-up")
        XCTAssertTrue(app.staticTexts["Ready for push-ups?"].waitForExistence(timeout: 3))
        app.buttons["Start a set"].tap()
        XCTAssertTrue(app.staticTexts["Checking shoulder and hand visibility"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDemoPushUpCanBeMeasuredWithoutPerformingOne() {
        let app = XCUIApplication()
        app.launchArguments.append("-plumb-ui-demo")
        app.launch()
        app.openHome()
        app.chooseExercise("Push-up")
        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["6 measured reps"].waitForExistence(timeout: 5))
        // The demo's last two reps also raise the hips above the body line: a form fault seen on two
        // reps comes before the change in elbow bend (15 October).
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Your hips rose above the line from your shoulders to your ankles in rep 5 and rep 6"))
            .firstMatch.exists)
    }

    @MainActor
    func testDemoLungeAndDeadliftProduceMeasuredSets() {
        for exercise in ["Static lunge", "Stiff-leg deadlift"] {
            let app = XCUIApplication()
            app.launchArguments.append("-plumb-ui-demo")
            app.launch()
            app.openHome()
                app.chooseExercise(exercise)
            app.buttons["Start a set"].tap()
            app.buttons["Start set"].tap()
            let stop = app.buttons["Stop set"]
            XCTAssertTrue(stop.waitForExistence(timeout: 6), exercise)
            Thread.sleep(forTimeInterval: 5)
            stop.tap()
            XCTAssertTrue(app.staticTexts["6 measured reps"].waitForExistence(timeout: 5), exercise)
            app.terminate()
        }
    }

    @MainActor
    func testDemoMissingWristRefusesPushUpWithoutInventingReps() {
        let app = XCUIApplication()
        app.launchArguments += ["-plumb-ui-demo", "-plumb-ui-demo-missing-wrist"]
        app.launch()
        app.openHome()
        app.chooseExercise("Push-up")
        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Couldn’t assess this set"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "wrist was hardest to see")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["6 measured reps"].exists)
    }

    @MainActor
    func testTrainedModelSwitchUsesDemoClassifierAndReportsIt() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-plumb-ui-demo", "-plumb-ui-demo-recognition"]
        app.launch()
        app.openHome()
        app.openFromHome("Options")
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
        XCTAssertTrue(app.buttons["Start a set"].waitForExistence(timeout: 5))

        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recognized as Squat on this iPhone."].exists)
    }
}
