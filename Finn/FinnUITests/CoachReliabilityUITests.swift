import XCTest

final class CoachReliabilityUITests: XCTestCase {
    @MainActor
    private func dismissKeyboardIntroduction(in app: XCUIApplication) {
        // iOS may explain its bilingual keyboard the first time a language is used.
        let tutorial = app.buttons.matching(NSPredicate(
            format: "label IN %@", ["Continue", "Continuer", "Continuar"])).firstMatch
        if tutorial.waitForExistence(timeout: 1) {
            tutorial.tap()
        }
    }
    /// This test deliberately disables inference; the separate native test requires Apple's model.
    @MainActor
    func testCoachAnswersWithoutAModelAndSurvivesTabChanges() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-AppleLanguages", "(en-GB)"]
        app.launch()
        app.selectTab("Coach")

        let field = app.textFields["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardIntroduction(in: app)
        field.typeText("My last set")
        XCTAssertTrue(app.buttons["coach.send"].isEnabled)
        app.buttons["coach.send"].tap()

        let answer = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "Finn has no saved set yet, so there is nothing to comment on."))
        XCTAssertTrue(answer.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["coach.dismissKeyboard"].tap()
        app.selectTab("Home")
        app.selectTab("Coach")

        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("What should I improve?\n")
        let secondAnswer = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 2"), object: answer)
        XCTAssertEqual(XCTWaiter().wait(for: [secondAnswer], timeout: 5), .completed)
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testCoachComposerAtLargestTextInEveryLanguage() {
        for language in ["en-GB", "en-US", "fr", "es"] {
            let app = XCUIApplication()
            app.launchArguments = ["-finn-ui-demo", "-AppleLanguages", "(\(language))",
                                   "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
            app.selectTab("Coach")
            let field = app.textFields["coach.field"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            dismissKeyboardIntroduction(in: app)
            field.typeText("Set 1?")
            let send = app.buttons["coach.send"]
            XCTAssertTrue(send.isHittable, language)
            let answers = app.descendants(matching: .any).matching(identifier: "coach.answer.fallback")
            let expectedCount = answers.count + 1
            send.tap()
            let replied = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", expectedCount), object: answers)
            XCTAssertEqual(XCTWaiter().wait(for: [replied], timeout: 8), .completed, "\(language): \(app.debugDescription)")
            XCTAssertTrue(app.buttons["coach.dismissKeyboard"].isHittable, language)
            app.buttons["coach.dismissKeyboard"].tap()
            app.terminate()
        }
    }

    @MainActor
    func testNativeAppleIntelligenceCoachAfterRecordedDemoSet() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FINN_NATIVE_COACH_TESTS"] == "1",
                          "Set TEST_RUNNER_FINN_NATIVE_COACH_TESTS=1 for real Apple Intelligence.")
        let app = XCUIApplication()
        // Only the camera feed is synthetic. The Coach uses the production on-device engine.
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-native-coach", "-AppleLanguages", "(en-GB)"]
        app.launch()
        app.selectTab("Coach")
        app.buttons["coach.engine"].tap()
        let modelAvailable = app.staticTexts[
            "Apple Intelligence chose the sets; the details come from Finn's records."].waitForExistence(timeout: 5)
        if !modelAvailable {
            let reason = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
            throw XCTSkip("Native model unavailable in this simulator: \(reason)")
        }
        app.buttons["Done"].tap()
        app.openWorkoutTab()
        app.buttons["Start a set"].tap()
        app.buttons["Start set"].tap()
        let reps = app.descendants(matching: .any)["capture.liveReps"]
        XCTAssertTrue(reps.waitForExistence(timeout: 6))
        let counted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", "0"), object: reps)
        XCTAssertEqual(XCTWaiter().wait(for: [counted], timeout: 10), .completed)
        app.buttons["Stop set"].tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
        app.selectTab("Coach")
        let field = app.textFields["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardIntroduction(in: app)
        field.typeText("How many reps did I do in set 1?")
        let answers = app.descendants(matching: .any).matching(identifier: "coach.answer.onDevice")
        let expectedCount = answers.count + 1
        app.buttons["coach.send"].tap()
        let answered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", expectedCount), object: answers)
        XCTAssertEqual(XCTWaiter().wait(for: [answered], timeout: 35), .completed,
                       "Expected a real on-device answer, not a fallback. \(app.debugDescription)")
        XCTAssertEqual(app.state, .runningForeground)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native Apple Intelligence Coach"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
