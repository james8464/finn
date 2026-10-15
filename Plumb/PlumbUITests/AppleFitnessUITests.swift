import XCTest

final class AppleFitnessUITests: XCTestCase {
    /// Demo input never reaches Apple Health: the option is shown, off, and cannot be turned on.
    /// (The live app's switch asks Health for permission, a system sheet these tests do not drive.)
    @MainActor
    func testFitnessOptionIsOffAndUnavailableWithDemoInput() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-plumb-ui-demo")
        app.launch()
        app.openWorkoutTab()
        app.openFromHome("Options")
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Apple Fitness"].exists)
        let toggle = app.switches["options.savesToFitness"]
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(toggle.isEnabled)
        // XCTest refuses identifier queries longer than 128 characters, so match the start.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "When you finish a session (Done, or Finish session")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Demo and recorded input are never saved to Apple Health."].exists)
    }
}
