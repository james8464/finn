import XCTest

/// Walks the arrival path and saves one full-screen PNG per screen, for design reviews.
///
/// It runs only when the test runner gets `PLUMB_CAPTURE_DIR` (pass it to xcodebuild as
/// `TEST_RUNNER_PLUMB_CAPTURE_DIR=/some/folder`), so CI skips it. The set screens use the
/// Debug demo feed, which shows DEMO INPUT: they show the interface, not a measured set.
final class ScreenTourUITests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        continueAfterFailure = true
        let path = ProcessInfo.processInfo.environment["PLUMB_CAPTURE_DIR"]
        try XCTSkipIf(path == nil, "Set TEST_RUNNER_PLUMB_CAPTURE_DIR to save the screen tour.")
        folder = URL(fileURLWithPath: path!, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// The first screen as a new user sees it, what Plumb says about the camera, then the
    /// system permission alert.
    @MainActor
    func test1FirstLaunch() {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .camera)
        app.launch()
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        save("01-premier-lancement-accueil")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        save("02-premier-lancement-accueil-bas")
        app.swipeDown()
        app.buttons["home.start"].tap()
        let primer = app.buttons["primer.continue"]
        if primer.waitForExistence(timeout: 5) {
            Thread.sleep(forTimeInterval: 1)
            save("03-premier-lancement-avant-camera")
            primer.tap()
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // The simulator may run in English or French.
        let allow = springboard.buttons.matching(NSPredicate(
            format: "(label ==[c] %@ OR label ==[c] %@ OR label ==[c] %@)", "Allow", "OK", "Autoriser")
        ).firstMatch
        if allow.waitForExistence(timeout: 8) {
            save("04-premier-lancement-autorisation-camera")
            allow.tap()
        }
    }

    @MainActor
    func test2HomeDarkAndExercises() {
        let dark = XCUIApplication()
        dark.launchArguments = ["-plumb-ui-dark"]
        dark.launch()
        dark.openWorkoutTab()
        XCTAssertTrue(dark.buttons["home.start"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        save("05-accueil-sombre")
        dark.terminate()

        let app = XCUIApplication()
        app.launch()
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
        app.buttons["Push-up"].tap()
        Thread.sleep(forTimeInterval: 1.2)
        save("06-choix-exercice-pompes")
        app.buttons["Stiff-leg deadlift"].tap()
        Thread.sleep(forTimeInterval: 1.2)
        save("07-choix-exercice-souleve")
        app.buttons["Static lunge"].tap()
        Thread.sleep(forTimeInterval: 1.2)
        save("07b-choix-exercice-fente")
        let pullUp = app.buttons["Pull-up"]
        if !pullUp.isHittable { app.buttons["Stiff-leg deadlift"].swipeLeft() }
        pullUp.tap()
        Thread.sleep(forTimeInterval: 1.2)
        save("07d-choix-exercice-tractions")
        app.buttons["home.more"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        save("07c-menu-plus")
    }

    @MainActor
    func test3SetPathWithDemoInput() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1.5)
        save("08-placement")
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 3)
        save("09-serie-en-cours")
        Thread.sleep(forTimeInterval: 1)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        save("10-resultat")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        save("11-resultat-bas")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        save("15-accueil-apres-une-serie")
    }

    @MainActor
    func test4OptionsPrivacyHistory() {
        let app = XCUIApplication()
        app.launch()
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
        open(app, "Options")
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        save("12-options")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["home.privacy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        save("13-confidentialite")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        open(app, "History")
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        save("14-historique")
    }

    /// Live advice during a demo set, as the person sees it from their spot, with demo poses that show
    /// a form fault on every rep: the squat's chest drops forward ("Chest up"), the push-up's hips sag
    /// ("Lift your hips"). Each
    /// screen is held for a while after a `ready-` file is written, so it can also be captured from
    /// outside with `xcrun simctl io <device> screenshot`.
    @MainActor
    func test5LiveAdviceWithDemoInput() {
        for (exercise, cue, name) in [("Squat", "Chest up", "16-conseil-en-direct-squat"),
                                      ("Push-up", "Lift your hips", "17-conseil-en-direct-pompes")] {
            let app = XCUIApplication()
            app.launchArguments = ["-plumb-ui-demo", "-plumb-ui-demo-form-fault"]
            app.launch()
            app.openWorkoutTab()
            XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
            app.buttons[exercise].tap()
            app.buttons["home.start"].tap()
            XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 8))
            app.buttons["Start set"].tap()
            let caption = app.staticTexts.matching(identifier: "capture.liveCaption").firstMatch
            XCTAssertTrue(caption.waitForExistence(timeout: 10))
            let shown = NSPredicate(format: "label == %@", cue)
            expectation(for: shown, evaluatedWith: caption)
            waitForExpectations(timeout: 10)
            Thread.sleep(forTimeInterval: 1)
            save(name)
            FileManager.default.createFile(atPath: folder.appending(path: "ready-\(name)").path, contents: nil)
            Thread.sleep(forTimeInterval: 12)
            app.terminate()
        }
    }

    // MARK: - Helpers

    /// Opens History, Options or Privacy from the first screen's More menu.
    @MainActor
    private func open(_ app: XCUIApplication, _ label: String) {
        app.buttons["home.more"].tap()
        let item = app.buttons[label].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.tap()
    }

    /// The whole screen, system sheets included.
    @MainActor
    private func save(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        do {
            try png.write(to: folder.appending(path: "\(name).png"))
        } catch {
            XCTFail("Could not save \(name): \(error)")
        }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
