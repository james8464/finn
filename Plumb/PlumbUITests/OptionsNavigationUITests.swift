import XCTest

final class OptionsNavigationUITests: XCTestCase {
    @MainActor
    func testReplayIsAccessibleFromAccountAndTheTopOfOptions() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        app.buttons["home.account"].tap()

        let accountReplay = app.buttons["account.replayOnboarding"]
        XCTAssertTrue(accountReplay.waitForExistence(timeout: 5))
        XCTAssertTrue(accountReplay.isHittable)
        accountReplay.tap()
        completeReplay(in: app)
        XCTAssertTrue(app.navigationBars["Account settings"].waitForExistence(timeout: 5))

        app.buttons["Options"].tap()
        let optionsReplay = app.buttons["options.replayOnboarding"]
        XCTAssertTrue(optionsReplay.waitForExistence(timeout: 5))
        XCTAssertTrue(optionsReplay.isHittable, "Replay must be visible without scrolling")
        optionsReplay.tap()
        completeReplay(in: app)
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 5))
        XCTAssertTrue(optionsReplay.isHittable)
    }

    @MainActor
    func testOptionsScrollsDownToHealthAndBackToWelcome() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        app.buttons["home.account"].tap()
        app.buttons["Options"].tap()
        let scroll = app.scrollViews["options.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let replay = app.buttons["options.replayOnboarding"]
        XCTAssertTrue(replay.isHittable)
        // Verify actual touch-drag scrolling, not just the presence of offscreen elements.
        let health = app.switches["options.personalizesWithHealth"]
        for _ in 0..<8 {
            if health.isHittable { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(health.isHittable, "Health settings must be reachable by scrolling")
        XCTAssertFalse(replay.isHittable)
        for _ in 0..<8 {
            if replay.isHittable { break }
            scroll.swipeDown()
        }
        XCTAssertTrue(replay.isHittable, "Scrolling back must reach the welcome shortcut")
    }

    @MainActor
    private func completeReplay(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.buttons["paywall.free"].waitForExistence(timeout: 5))
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForNonExistence(timeout: 5))
    }
}
