import XCTest

/// Navigation regression checks, with optional screenshots for the design review.
final class NativeUIReviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testNativeDestinations() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Summary"].waitForExistence(timeout: 8))
        try save("summary")
        app.selectTab("Workout")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        try save("workout")
        app.selectTab("History")
        XCTAssertTrue(app.staticTexts["No saved sessions yet."].waitForExistence(timeout: 3))
        try save("history-empty")
        app.selectTab("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        try save("coach")
        app.buttons["coach.engine"].tap()
        XCTAssertTrue(app.navigationBars["About Coach"].waitForExistence(timeout: 3))
        try save("coach-source")
        app.buttons["Done"].tap()
        app.selectTab("Summary")
        app.buttons["home.account"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        try save("settings")
        app.buttons["Options"].tap()
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 3))
        try save("options")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Privacy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 3))
        try save("privacy")
    }

    @MainActor
    func testDarkAppearanceAndLargestText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-plumb-ui-dark"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Summary"].waitForExistence(timeout: 8))
        try save("summary-dark")
        app.openWorkoutTab()
        try save("workout-dark")
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Summary"].waitForExistence(timeout: 8))
        try save("summary-largest-text")
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].isHittable)
        try save("workout-largest-text")
        app.selectTab("Coach")
        let field = app.textFields["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("My last set")
        XCTAssertTrue(app.buttons["coach.send"].isHittable)
        try save("coach-largest-text-keyboard")
        app.buttons["coach.send"].tap()
        XCTAssertTrue(app.staticTexts["My last set"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFrenchNavigationAndBestSet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Résumé"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["summary.workout"].label.contains("Choisir"))
        try save("summary-french")
        let best = app.buttons["home.weights"]
        if !best.isHittable { app.swipeUp() }
        best.tap()
        XCTAssertTrue(app.navigationBars["Meilleure série"].waitForExistence(timeout: 3))
        app.selectTab("Séance")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        try save("workout-french")
    }

    @MainActor
    func testHealthOfferAtLargestText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-plumb-open", "health",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["offer.later"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["offer.later"].isHittable)
        XCTAssertTrue(app.buttons["offer.personalize"].isHittable)
        XCTAssertTrue(app.staticTexts["Make Plumb more personal?"].exists)
        try save("health-offer-largest-text")
        app.buttons["offer.later"].tap()
        XCTAssertTrue(app.tabBars.buttons["Summary"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func save(_ name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["PLUMB_CAPTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        // Let native navigation/material transitions settle before capturing.
        Thread.sleep(forTimeInterval: 0.5)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url.appending(path: "\(name).png"))
    }
}
