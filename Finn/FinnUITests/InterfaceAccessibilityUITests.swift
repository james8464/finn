import XCTest

/// Repeatable visual coverage of the app, using isolated demo data rather than personal history.
final class InterfaceAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    @MainActor func testSupportingScreens() throws { try supportingScreens(large: false) }
    @MainActor func testSupportingScreensLargestText() throws { try supportingScreens(large: true) }
    @MainActor func testWelcomeAndDemo() throws { try welcomeAndDemo(large: false) }
    @MainActor func testWelcomeAndDemoLargestText() throws { try welcomeAndDemo(large: true) }
    @MainActor func testWorkoutAndSavedScreens() throws { try workoutAndSavedScreens(large: false) }
    @MainActor func testWorkoutAndSavedScreensLargestText() throws { try workoutAndSavedScreens(large: true) }

    @MainActor func testHomeDetailTextScales() {
        let regular = launch(large: false)
        let caption = regular.staticTexts["No workouts yet"]
        XCTAssertTrue(caption.waitForExistence(timeout: 8))
        let regularHeight = caption.frame.height
        regular.terminate()
        let large = launch(large: true)
        let scaledCaption = large.staticTexts["No workouts yet"]
        XCTAssertTrue(scaledCaption.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(scaledCaption.frame.height, regularHeight * 1.5,
                             "Home captions must follow the person's text-size setting")
    }

    @MainActor private func launch(large: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"] + extra
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }

    @MainActor private func supportingScreens(large: Bool) throws {
        try requireCaptureDirectory()
        let prefix = large ? "large" : "regular"
        let app = launch(large: large, extra: ["-finn-ui-badges-demo"])
        XCTAssertTrue(app.buttons["home.tryFinn"].waitForExistence(timeout: 8))
        try check(app, "\(prefix)-01-home")
        for id in ["home.lastSession", "home.posture", "home.weights", "home.sessions", "home.awards"] {
            let card = app.buttons[id]
            for _ in 0..<6 where !card.isHittable { app.swipeUp() }
            card.tap()
            try check(app, "\(prefix)-02-\(id)")
            if id == "home.awards" {
                app.buttons["badge.row"].firstMatch.tap()
                try check(app, "\(prefix)-03-award-detail")
                for _ in 0..<12 where !app.buttons["Done"].isHittable { app.scrollViews.firstMatch.swipeUp() }
                app.buttons["Done"].tap()
            }
            if id == "home.posture" { app.selectTab("Home") }
            else { app.navigationBars.buttons.element(boundBy: 0).tap() }
        }
        try check(app, "\(prefix)-04-home-bottom")
        // iOS 27 can report an offscreen scroll child as hittable. Start the
        // settings survey from a fresh Home instead of tapping that stale node.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.account"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.account"].isHittable)
        app.buttons["home.account"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try check(app, "\(prefix)-05-settings")
        app.buttons["Options"].tap()
        try check(app, "\(prefix)-06-options-top")
        app.swipeUp()
        try check(app, "\(prefix)-07-options-middle")
        app.swipeUp()
        try check(app, "\(prefix)-08-options-bottom")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Privacy"].tap()
        try check(app, "\(prefix)-09-privacy-top")
        for index in 1...3 {
            app.swipeUp()
            try check(app, "\(prefix)-10-privacy-\(index)")
        }
        app.selectTab("Posture")
        try check(app, "\(prefix)-11-posture")
        app.selectTab("Coach")
        try check(app, "\(prefix)-12-coach")
        app.buttons["coach.engine"].tap()
        try check(app, "\(prefix)-13-about-coach")
        app.terminate()
        let health = launch(large: large, extra: ["-finn-open", "health"])
        XCTAssertTrue(health.buttons["offer.later"].waitForExistence(timeout: 8))
        try check(health, "\(prefix)-14-health")
        health.terminate()
        let primer = launch(large: large, extra: ["-finn-open", "camera-primer"])
        XCTAssertTrue(primer.buttons["primer.continue"].waitForExistence(timeout: 8))
        try check(primer, "\(prefix)-15-camera-primer")
    }

    @MainActor private func welcomeAndDemo(large: Bool) throws {
        try requireCaptureDirectory()
        let prefix = large ? "large" : "regular"
        let app = launch(large: large, extra: ["-finn-ui-onboarding"])
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8))
        for step in 1...5 {
            try check(app, "\(prefix)-20-welcome-\(step)")
            let last: XCUIElement
            switch step {
            case 1: last = app.buttons["onboarding.goal.comeback"]
            case 2: last = app.buttons["onboarding.exercise.muscleUp"]
            case 3: last = app.buttons["onboarding.level.experienced"]
            case 4: last = app.staticTexts["Audio plays through connected headphones or the iPhone speaker."]
            default: last = app.descendants(matching: .any).matching(NSPredicate(
                format: "label BEGINSWITH %@", "The camera is asked for when you start your first set")).firstMatch
            }
            for _ in 0..<16 where !last.isHittable { app.scrollViews.firstMatch.swipeUp() }
            app.scrollViews.firstMatch.swipeUp()
            try check(app, "\(prefix)-21-welcome-\(step)-bottom")
            app.buttons["onboarding.continue"].tap()
        }
        XCTAssertTrue(app.buttons["home.watchDemo"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 2)
        app.buttons["home.watchDemo"].tap()
        XCTAssertTrue(app.buttons["demo.continue"].waitForExistence(timeout: 5))
        try check(app, "\(prefix)-22-demo")
        try demoBottom(app, name: "\(prefix)-22-demo-bottom")
        app.buttons["demo.continue"].tap()
        try check(app, "\(prefix)-23-demo-advice")
        try demoBottom(app, name: "\(prefix)-23-demo-advice-bottom")
    }

    @MainActor private func workoutAndSavedScreens(large: Bool) throws {
        try requireCaptureDirectory()
        let prefix = large ? "large" : "regular"
        let app = launch(large: large)
        app.openWorkoutTab()
        try check(app, "\(prefix)-30-workout")
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 8))
        try check(app, "\(prefix)-31-framing")
        app.buttons["Start set"].tap()
        XCTAssertTrue(app.buttons["Stop set"].waitForExistence(timeout: 8))
        try check(app, "\(prefix)-32-capture")
        app.buttons["Stop set"].tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 8))
        try check(app, "\(prefix)-33-result")
        app.swipeUp()
        try check(app, "\(prefix)-34-result-bottom")
        let share = app.buttons["result.shareSummary"]
        for _ in 0..<12 where !share.isHittable { app.scrollViews.firstMatch.swipeUp() }
        app.scrollViews.firstMatch.swipeUp()
        try check(app, "\(prefix)-34-result-end")
        app.buttons["Done"].tap()
        app.openWorkoutTab()
        app.openFromHome("History")
        try check(app, "\(prefix)-35-history")
        let session = app.buttons["history.session"].firstMatch
        for _ in 0..<8 where !session.isHittable { app.swipeUp() }
        session.tap()
        try check(app, "\(prefix)-36-session")
        app.swipeUp()
        try check(app, "\(prefix)-37-session-bottom")
        app.terminate()
        let error = launch(large: large, extra: ["-finn-ui-camera-unavailable"])
        error.openWorkoutTab()
        error.buttons["home.start"].tap()
        XCTAssertTrue(error.buttons["Try again"].waitForExistence(timeout: 8))
        try check(error, "\(prefix)-38-camera-unavailable")
    }

    @MainActor private func check(_ app: XCUIApplication, _ name: String) throws {
        // Native sheet and navigation animations may outlive the accessibility tree update.
        Thread.sleep(forTimeInterval: 2)
        if let path = ProcessInfo.processInfo.environment["FINN_CAPTURE_DIR"] {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appending(path: name + ".png"))
        }
        // The iOS 27 image scanner also inspects hidden tabs and offscreen scroll content.
        // Keep the full diagnostic scan available; verify contrast from rendered pixels
        // and PaletteAccessibilityTests instead of treating those reports as proof.
        let fullScan = ProcessInfo.processInfo.environment["FINN_FULL_ACCESSIBILITY_AUDIT"] == "1"
        let types: XCUIAccessibilityAuditType = fullScan
            ? [.contrast, .textClipped, .hitRegion, .dynamicType] : [.textClipped, .hitRegion]
        try app.performAccessibilityAudit(for: types) { issue in
            let element = issue.element.map { "'\($0.label)' at \($0.frame)" } ?? "no element"
            let detail = "\(name): \(issue.compactDescription). \(issue.detailedDescription) \(element)"
            print("INTERFACE_AUDIT \(detail)")
            XCTFail(detail)
            return true
        }
    }

    private func requireCaptureDirectory() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["FINN_CAPTURE_DIR"] == nil,
                      "Manual screen survey: set TEST_RUNNER_FINN_CAPTURE_DIR to save and review the audit evidence.")
    }

    @MainActor private func demoBottom(_ app: XCUIApplication, name: String) throws {
        let disclaimer = app.staticTexts["Illustrated demo · sample reps and advice"]
        for _ in 0..<12 where !disclaimer.isHittable { app.scrollViews.firstMatch.swipeUp() }
        app.scrollViews.firstMatch.swipeUp()
        try check(app, name)
    }
}
