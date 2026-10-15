import XCTest

/// Saves one PNG per welcome screen, the Awards screen with a few badges, and the Home card.
/// Runs only with `TEST_RUNNER_FINN_CAPTURE_DIR`, like `ScreenTourUITests`.
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
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.8)
        save("onboarding-1-objectif")
        app.buttons["onboarding.goal.technique"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        save("onboarding-1-objectif-choisi")
        next.tap()
        Thread.sleep(forTimeInterval: 0.8)
        app.buttons["onboarding.exercise.pushUp"].tap()
        app.buttons["onboarding.exercise.bodyweightSquat"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        save("onboarding-2-exercices")
        next.tap()
        Thread.sleep(forTimeInterval: 0.8)
        app.buttons["onboarding.level.regular"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        save("onboarding-3-niveau")
        next.tap()
        Thread.sleep(forTimeInterval: 0.8)
        save("onboarding-4-voix")
        next.tap()
        Thread.sleep(forTimeInterval: 1.2)
        save("onboarding-5-placement")
        next.tap()
        // The first favorite (push-up) is the exercise ready on the Workout tab.
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        save("onboarding-6-apres-pompes-en-premier")
    }

    @MainActor
    func test2Badges() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-badges-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        let awards = app.buttons["home.awards"]
        for _ in 0..<4 where !awards.isHittable { app.swipeUp() }
        XCTAssertTrue(awards.isHittable)
        Thread.sleep(forTimeInterval: 1)
        save("accueil-carte-awards")
        app.buttons["home.awards"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "badges.summary").firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        save("badges-1-haut")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        save("badges-2-bas")
        app.terminate()

        let empty = XCUIApplication()
        empty.launchArguments = ["-finn-ui-demo", "-finn-open", "awards"]
        empty.launch()
        XCTAssertTrue(empty.descendants(matching: .any).matching(identifier: "badges.empty").firstMatch.waitForExistence(timeout: 8))
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
