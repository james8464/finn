import XCTest

final class ExerciseOptionsUITests: XCTestCase {
    @MainActor
    func testOptionsExplainAngleRulesAndTurnThemOnByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-finn-ui-demo")
        app.launch()
        app.openWorkoutTab()
        app.openFromHome("Options")
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 5))
        let toggle = app.switches["options.recogniseExercise"]
        app.reveal(toggle)
        XCTAssertTrue(app.staticTexts["Estimates from joint angles; uses your selection when uncertain."].exists)
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
        app.launchArguments.append("-finn-ui-demo")
        app.launch()
        app.openWorkoutTab()
        let squat = app.buttons["Squat"]
        XCTAssertTrue(squat.waitForExistence(timeout: 5))
        XCTAssertTrue(squat.isSelected)
        XCTAssertTrue(squat.isHittable, "The selected exercise must be visible on first launch")
        let pushUp = app.buttons["Push-up"]
        pushUp.tap()
        XCTAssertTrue(pushUp.isSelected)
        XCTAssertFalse(squat.isSelected)
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "On the floor or a low step")).firstMatch.exists)
        app.buttons["Start a set"].tap()
        XCTAssertTrue(app.staticTexts["Checking shoulder and hand visibility"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDemoPushUpCanBeMeasuredWithoutPerformingOne() {
        let app = XCUIApplication()
        app.launchArguments.append("-finn-ui-demo")
        app.launch()
        app.openWorkoutTab()
        app.buttons["Push-up"].tap()
        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["6 measured reps"].waitForExistence(timeout: 5))
        // the demo's last two reps also raise the hips above the body line: a form fault seen on two
        // reps comes before the change in elbow bend (15 October)
        let observation = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Your hips rose above your body line in rep 5 and rep 6"))
            .firstMatch
        XCTAssertTrue(observation.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testDemoLungeAndDeadliftProduceMeasuredSets() {
        for exercise in ["Static lunge", "Stiff-leg deadlift"] {
            let app = XCUIApplication()
            app.launchArguments.append("-finn-ui-demo")
            app.launch()
            app.openWorkoutTab()
                app.buttons[exercise].tap()
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
        app.launchArguments += ["-finn-ui-demo", "-finn-ui-demo-missing-wrist"]
        app.launch()
        app.openWorkoutTab()
        app.buttons["Push-up"].tap()
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
        app.launchArguments += ["-finn-ui-demo", "-finn-ui-demo-recognition"]
        app.launch()
        app.openWorkoutTab()
        app.openFromHome("Options")
        app.reveal(app.switches["options.recogniseExercise"])
        XCTAssertEqual(app.switches["options.recogniseExercise"].value as? String, "1")
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
