import XCTest

/// The first screen, primary tabs, and the More menu.
final class HomeUITests: XCTestCase {
    @MainActor
    func testEveryPageOpensFromItsTabOrMoreMenuAndComesBack() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        app.openHome()
        XCTAssertTrue(app.tabBars.firstMatch.exists, "The primary tabs are missing")
        for page in ["Stats", "Coach", "Awards"] {
            app.openFromHome(page)
            XCTAssertTrue(app.navigationBars[page].waitForExistence(timeout: 5), page)
            if page == "Coach" { XCTAssertTrue(app.textFields["coach.field"].exists) }
            app.tabBars.buttons["figure.strengthtraining.functional"].tap()
            XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5), "Back from \(page)")
        }
        for page in ["Options", "Privacy"] {
            app.openFromHome(page)
            XCTAssertTrue(app.navigationBars[page].waitForExistence(timeout: 5), page)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5), "Back from \(page)")
        }
    }

    @MainActor
    func testTitleFollowsTheChosenExercise() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        app.openHome()
        XCTAssertTrue(app.staticTexts["Ready for squats?"].exists)
        app.chooseExercise("Push-up")
        XCTAssertTrue(app.staticTexts["Ready for push-ups?"].waitForExistence(timeout: 3))
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.staticTexts["Checking shoulder and hand visibility"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavedSetShowsOnTheFirstScreen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo"]
        app.launch()
        app.openHome()
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
        let line = app.buttons["home.progress"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.contains("this week"), line.label)
    }

    @MainActor
    func testLargeTextKeepsTheFirstScreenUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-plumb-ui-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.openHome()
        XCTAssertTrue(app.buttons["home.start"].isHittable)
        XCTAssertTrue(app.buttons["home.more"].isHittable)
        app.openFromHome("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testHomeAndNavigationInAllSupportedLanguages() {
        for (code, start, awards, options) in [
            ("en-GB", "Start a set", "Awards", "Options"),
            ("en-US", "Start a set", "Awards", "Options"),
            ("fr", "Commencer une série", "Récompenses", "Options"),
            ("es", "Inicia una serie", "Premios", "Opciones"),
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["-plumb-ui-demo", "-AppleLanguages", "(\(code))"]
            app.launch()
            XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8), code)
            XCTAssertEqual(app.buttons["home.start"].label, start, code)
            XCTAssertEqual(app.tabBars.buttons["rosette"].label, awards, code)
            app.buttons["home.more"].tap()
            XCTAssertTrue(app.buttons[options].waitForExistence(timeout: 3), code)
            app.terminate()
        }
    }
}
