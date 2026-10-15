import XCTest

final class DashboardUITests: XCTestCase {
    /// exercises the real launch path in both Debug and Release; no synthetic-input flags
    @MainActor
    func testProductionLaunchRendersAllTabsAndDestinations() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        app.skipOnboardingIfShown()
        XCTAssertTrue(app.scrollViews["summary.scroll"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.tryFinn"].isHittable)
        app.selectTab("Posture")
        XCTAssertTrue(app.scrollViews["posture.guide"].waitForExistence(timeout: 5))
        app.selectTab("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 5))
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.start"].isHittable)
        app.openFromHome("Options")
        XCTAssertTrue(app.buttons["options.hapticFeedback"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.openFromHome("Privacy")
        XCTAssertTrue(app.buttons["privacy.camera"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Production privacy destination"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testOriginalHomeScrollPositionSurvivesTabSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        let scroll = app.scrollViews["summary.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.tryFinn"].isHittable)
        scroll.swipeUp()
        XCTAssertTrue(app.buttons["home.awards"].isHittable)
        let position = app.buttons["home.awards"].frame.minY
        app.selectTab("Workout")
        app.selectTab("Home")
        XCTAssertEqual(app.buttons["home.awards"].frame.minY, position, accuracy: 3)
        scroll.swipeDown()
        XCTAssertTrue(app.buttons["home.tryFinn"].isHittable)
    }

    @MainActor
    func testRestoredDemoNeverWritesHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["home.watchDemo"].waitForExistence(timeout: 8))
        app.buttons["home.watchDemo"].tap()
        XCTAssertTrue(app.buttons["demo.continue"].waitForExistence(timeout: 5))
        app.buttons["demo.continue"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["demo.advice"].waitForExistence(timeout: 3))
        app.buttons["demo.continue"].tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        app.selectTab("Home")
        XCTAssertTrue(app.staticTexts["No workouts yet"].exists)
    }

    @MainActor
    func testAllDashboardDestinationsAndTabs() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["tab.home"].isSelected)
        XCTAssertFalse(app.staticTexts["42:18"].exists)
        XCTAssertFalse(app.staticTexts["Not made yet"].exists)
        app.swipeUp()
        app.buttons["home.sessions"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.selectTab("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        app.selectTab("Posture")
        XCTAssertTrue(app.navigationBars["Posture"].waitForExistence(timeout: 3))
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Squat"].exists)
        app.selectTab("Home")
        app.buttons["home.awards"].tap()
        XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 3))
        app.selectTab("Workout")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        app.selectTab("Home")
        XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeDown()
        app.buttons["home.account"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        app.buttons["Options"].tap()
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Privacy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPostureCardOpensThePostureTabAndExerciseGuide() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        let card = app.buttons["home.posture"]
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.tap()
        XCTAssertTrue(app.buttons["tab.posture"].isSelected)
        XCTAssertTrue(app.scrollViews["posture.guide"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["posture.exercise.pushUp"].exists)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "Posture guide"
        image.lifetime = .keepAlways
        add(image)
    }

    @MainActor
    func testFrenchDashboardUsesFrenchForMainActionsAndEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-AppleLanguages", "(fr)",
                               "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Essayer Finn"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.watchDemo"].label.contains("Voir la démo"))
        XCTAssertTrue(app.staticTexts["Aucune séance pour l’instant"].exists)
        XCTAssertTrue(app.staticTexts["Voir le guide du mouvement"].exists)
    }

    @MainActor
    func testHomeAndPostureNavigationInSupportedLanguages() {
        for (language, region, tryLabel, startLabel) in [
            ("en-GB", "en_GB", "Try Finn", "Start a set"),
            ("en-US", "en_US", "Try Finn", "Start a set"),
            ("fr", "fr_FR", "Essayer Finn", "Commencer une série"),
            ("es", "es_ES", "Prueba Finn", "Inicia una serie"),
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["-finn-ui-demo", "-AppleLanguages", "(\(language))",
                                   "-AppleLocale", region]
            app.launch()
            XCTAssertTrue(app.staticTexts[tryLabel].waitForExistence(timeout: 8), language)
            app.buttons["home.posture"].tap()
            XCTAssertTrue(app.scrollViews["posture.guide"].waitForExistence(timeout: 3), language)
            app.openWorkoutTab()
            XCTAssertEqual(app.buttons["home.start"].label, startLabel, language)
            app.terminate()
        }
    }

    @MainActor
    func testSavedWorkoutAppearsOnDashboard() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        app.openWorkoutTab()
        app.buttons["home.start"].tap()
        let start = app.buttons["Start set"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 8))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        app.selectTab("Home")
        XCTAssertFalse(app.staticTexts["No workouts yet"].exists)
        XCTAssertTrue(app.buttons["home.lastSession"].isHittable)
        let savedPosition = app.buttons["home.lastSession"].frame.minY
        app.selectTab("Workout")
        app.selectTab("Home")
        XCTAssertEqual(app.buttons["home.lastSession"].frame.minY, savedPosition, accuracy: 3)
        app.buttons["home.lastSession"].tap()
        XCTAssertTrue(app.navigationBars["Session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.disclosureTriangles["About measurements"].exists || app.buttons["About measurements"].exists)
        try saveWidget("session")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeUp()
        app.buttons["home.sessions"].tap()
        XCTAssertTrue(app.staticTexts["Total reps"].waitForExistence(timeout: 5))
        try saveWidget("statistics")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["home.awards"].tap()
        XCTAssertTrue(app.buttons["badge.row"].firstMatch.waitForExistence(timeout: 5))
        try saveWidget("awards")
        app.buttons["badge.row"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["badges.detail"].waitForExistence(timeout: 5))
        try saveWidget("award-detail")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Awards"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testNestedNavigationSurvivesCameraPresentation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        app.buttons["home.account"].tap()
        app.buttons["Options"].tap()
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 3))
        app.openWorkoutTab()
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.selectTab("Home")
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 3),
                      "Returning from the camera must preserve nested tab navigation")
    }

    @MainActor
    func testLargeTextKeepsNavigationUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.account"].isHittable)
        app.selectTab("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        app.selectTab("Home")
        let scroll = app.scrollViews["summary.scroll"]
        for _ in 0..<6 where !app.buttons["home.awards"].isHittable { scroll.swipeUp() }
        XCTAssertTrue(app.buttons["home.awards"].isHittable)
    }
    @MainActor
    private func saveWidget(_ name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["FINN_CAPTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url.appending(path: "\(name).png"))
    }

}
