import XCTest

final class StartupUITests: XCTestCase {
    @MainActor
    func testColdLaunchAndReturnPreserveNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        app.skipOnboardingIfShown()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["launch.loading"].exists)
        app.selectTab("Workout")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["launch.loading"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Returned to Finn"
        capture.lifetime = .keepAlways
        add(capture)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.otherElements["launch.loading"].exists)
    }
}
