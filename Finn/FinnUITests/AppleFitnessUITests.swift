import XCTest

final class AppleFitnessUITests: XCTestCase {
    /// Demo input never reaches Apple Health: the option is shown, off, and cannot be turned on.
    /// (The live app's switch asks Health for permission, a system sheet these tests do not drive.)
    @MainActor
    func testFitnessOptionIsOffAndUnavailableWithDemoInput() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-finn-ui-demo")
        app.launch()
        app.openWorkoutTab()
        app.openFromHome("Options")
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 5))
        let toggle = app.switches["options.savesToFitness"]
        app.reveal(toggle)
        XCTAssertTrue(app.staticTexts["Apple Fitness"].exists)
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(toggle.isEnabled)
        XCTAssertTrue(app.staticTexts["Saves finished sessions with duration and reps, without calorie or heart-rate estimates."].exists)
        XCTAssertTrue(app.staticTexts["Demo and recorded input are never saved to Apple Health."].exists)
    }
}
