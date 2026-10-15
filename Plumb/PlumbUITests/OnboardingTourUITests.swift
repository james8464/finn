import XCTest

/// Saves one PNG per welcome screen, the Awards screen with a few badges, and the Home card.
/// Runs only with `TEST_RUNNER_PLUMB_CAPTURE_DIR`, like `ScreenTourUITests`.
final class OnboardingTourUITests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        continueAfterFailure = true
        let path = ProcessInfo.processInfo.environment["PLUMB_CAPTURE_DIR"]
        try XCTSkipIf(path == nil, "Set TEST_RUNNER_PLUMB_CAPTURE_DIR to save the tour.")
        folder = URL(fileURLWithPath: path!, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @MainActor
    func test1Onboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-plumb-ui-onboarding"]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        save("onboarding-1-welcome")
        next.tap()
        XCTAssertTrue(app.otherElements["demo.capture"].waitForExistence(timeout: 5))
        save("onboarding-2-demo-capture")
        next.tap()
        XCTAssertTrue(app.otherElements["demo.advice"].waitForExistence(timeout: 5))
        save("onboarding-3-demo-advice")
        next.tap()
        XCTAssertTrue(app.buttons["paywall.free"].waitForExistence(timeout: 5))
        save("onboarding-4-choose-coach")
        let annual = app.buttons["paywall.annual"]
        if !annual.isHittable { app.swipeUp() }
        annual.tap()
        save("onboarding-5-annual")
        next.tap()
        XCTAssertTrue(app.buttons["home.tryPlumb"].waitForExistence(timeout: 8))
        save("onboarding-6-home")
    }

    @MainActor
    func test2Badges() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-plumb-ui-badges-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["home.awards"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        save("accueil-carte-awards")
        app.buttons["home.awards"].tap()
        XCTAssertTrue(app.staticTexts["badges.count"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        save("badges-1-haut")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        save("badges-2-bas")
        app.terminate()

        let empty = XCUIApplication()
        empty.launchArguments = ["-plumb-ui-demo", "-plumb-open", "awards"]
        empty.launch()
        XCTAssertTrue(empty.otherElements["badges.empty"].waitForExistence(timeout: 8)
                      || empty.staticTexts["Your first badge is one set away."].waitForExistence(timeout: 2))
        Thread.sleep(forTimeInterval: 0.8)
        save("badges-0-vide")
    }

    @MainActor
    private func save(_ name: String) {
        // Let the page/selection transition finish before freezing the design preview.
        Thread.sleep(forTimeInterval: 0.3)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        do { try png.write(to: folder.appending(path: "\(name).png")) }
        catch { XCTFail("Could not save \(name): \(error)") }
    }
}
