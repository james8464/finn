import XCTest

final class WatchCompanionUITests: XCTestCase {
    /// Keeps each stage visible long enough for a paired Watch simulator screenshot.
    @MainActor
    func testDemoSetMirrorsToPairedWatch() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-watch-demo"]
        app.launch()
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 8))
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 8))
        print("WATCH_CAPTURE_WINDOW")
        Thread.sleep(forTimeInterval: 15)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 8))
        print("WATCH_RESULT_WINDOW")
        Thread.sleep(forTimeInterval: 6)
    }
}
