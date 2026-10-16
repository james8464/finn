import XCTest

/// saves one PNG per onboarding screen and Finn reaction, the Awards screen with a few badges, and the Home card
/// runs only with `TEST_RUNNER_FINN_CAPTURE_DIR`, like `ScreenTourUITests`
final class OnboardingTourUITests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let path = ProcessInfo.processInfo.environment["FINN_CAPTURE_DIR"]
        try XCTSkipIf(path == nil, "Set TEST_RUNNER_FINN_CAPTURE_DIR to save the tour.")
        folder = URL(fileURLWithPath: path!, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @MainActor
    func test1Onboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-onboarding"]
        app.launch()
        let welcome = app.buttons["onboarding.welcome.continue"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.8)
        save("onboarding-0-accueil")
        welcome.tap()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.8)
        save("onboarding-1-demo-coaching")
        next.tap()
        Thread.sleep(forTimeInterval: 0.8)
        save("onboarding-2-demo-montre")
        next.tap()
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        // Continue waits for a first name
        XCTAssertFalse(next.isEnabled)
        save("onboarding-3-prenom-vide")
        name.tap()
        app.typeText("Alex")
        XCTAssertTrue(next.isEnabled)
        save("onboarding-3-prenom")
        next.tap()
        Thread.sleep(forTimeInterval: 0.8)
        app.buttons["onboarding.goal.technique"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        save("onboarding-4-objectif-choisi")
        answer(next, then: "onboarding-4-objectif", waitFor: "onboarding.level.regular")
        app.buttons["onboarding.level.regular"].tap()
        answer(next, then: "onboarding-5-niveau", waitFor: "onboarding.program.yes")
        app.buttons["onboarding.program.yes"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        save("onboarding-6-programme-oui")
        app.buttons["onboarding.stopReason.injury"].tap()
        app.buttons["onboarding.stopReason.motivation"].tap()
        app.scrollViews.firstMatch.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        save("onboarding-6-programme-raisons")
        answer(next, then: "onboarding-6-programme", waitFor: "onboarding.intensity.challenge")
        app.buttons["onboarding.intensity.challenge"].tap()
        answer(next, then: "onboarding-7-intensite", waitFor: "onboarding.days.threeToFour")
        app.buttons["onboarding.days.threeToFour"].tap()
        answer(next, then: "onboarding-8-jours", waitFor: "plan.skip")
        Thread.sleep(forTimeInterval: 0.8)
        save("onboarding-9-offre")
        app.buttons["plan.annual"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        save("onboarding-9-offre-annuel")
        app.buttons["plan.trial"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        save("onboarding-9-offre-essai")
        app.buttons["plan.skip"].tap()
        let access = app.buttons["aboutYou.access"]
        XCTAssertTrue(access.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        save("onboarding-10-a-propos")
        app.buttons["aboutYou.location"].tap()
        app.buttons["Gym"].tap()
        app.buttons["aboutYou.equipment"].tap()
        app.buttons["Pull-up bar"].tap()
        app.buttons["Dumbbells"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        save("onboarding-10-a-propos-materiel")
        // the equipment menu stays open while ticking; a tap outside closes it
        app.staticTexts["A little more about you."].tap()
        for _ in 0 ..< 6 where !access.isHittable {
            app.swipeUp()
        }
        XCTAssertFalse(access.isEnabled)
        app.buttons["aboutYou.noInjuries"].tap()
        XCTAssertTrue(access.isEnabled)
        Thread.sleep(forTimeInterval: 0.5)
        save("onboarding-10-a-propos-bas")
        access.tap()
        // the app opens on Home, with Try Finn
        XCTAssertTrue(app.buttons["home.tryFinn"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        save("onboarding-11-accueil-try-finn")
    }

    /// Continue with an answer chosen: Finn's LEDs, then the line, then the next screen by itself
    @MainActor
    private func answer(_ next: XCUIElement, then name: String, waitFor identifier: String) {
        next.tap()
        Thread.sleep(forTimeInterval: 0.3)
        save("\(name)-finn-leds")
        Thread.sleep(forTimeInterval: 0.9)
        save("\(name)-finn")
        // the next page is laid out beside this one, so wait until it is the one on screen
        let target = XCUIApplication().buttons[identifier]
        let onScreen = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: target)
        wait(for: [onScreen], timeout: 6)
        Thread.sleep(forTimeInterval: 0.8)
    }

    @MainActor
    func test2Badges() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-badges-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        let awards = app.buttons["home.awards"]
        for _ in 0 ..< 4 where !awards.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(awards.isHittable)
        Thread.sleep(forTimeInterval: 1)
        save("accueil-carte-awards")
        app.buttons["home.awards"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "badges.summary").firstMatch
            .waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        save("badges-1-haut")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        save("badges-2-bas")
        app.terminate()

        let empty = XCUIApplication()
        empty.launchArguments = ["-finn-ui-demo", "-finn-open", "awards"]
        empty.launch()
        XCTAssertTrue(empty.descendants(matching: .any).matching(identifier: "badges.empty").firstMatch
            .waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.8)
        save("badges-0-vide")
    }

    @MainActor
    private func save(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        do { try png.write(to: folder.appending(path: "\(name).png")) }
        catch { XCTFail("Could not save \(name): \(error)") }
    }
}
