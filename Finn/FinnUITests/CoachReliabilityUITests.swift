import XCTest

final class CoachReliabilityUITests: XCTestCase {
    @MainActor
    private func dismissKeyboardIntroduction(in app: XCUIApplication) {
        // iOS may explain its bilingual keyboard the first time a language is used.
        let tutorial = app.buttons.matching(NSPredicate(
            format: "label IN %@", ["Continue", "Continuer", "Continuar"]
        )).firstMatch
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

        let field = app.textViews["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardIntroduction(in: app)
        field.typeText("My last set")
        XCTAssertTrue(app.buttons["coach.send"].isEnabled)
        app.buttons["coach.send"].tap()

        let answer = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "Finn has no saved set yet, so there is nothing to comment on."
        ))
        XCTAssertTrue(answer.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["coach.dismissKeyboard"].tap()
        app.selectTab("Home")
        app.selectTab("Coach")

        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("What should I improve?\n")
        let submittedQuestion = app.staticTexts["What should I improve?"]
        XCTAssertTrue(submittedQuestion.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["coach.send"].isEnabled, app.debugDescription)
        XCTAssertTrue(answer.firstMatch.waitForExistence(timeout: 5))
        // Lazy transcript rows can be discarded outside the viewport. Verify the visible reply
        // follows the newly submitted question instead of counting off-screen answer views.
        let latestAnswer = answer.element(boundBy: max(0, answer.count - 1))
        XCTAssertGreaterThan(latestAnswer.frame.minY, submittedQuestion.frame.minY)
        XCTAssertLessThanOrEqual(
            latestAnswer.frame.maxY,
            field.frame.minY - 8,
            "The new reply must remain above the composer and keyboard"
        )
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testCoachComposerAtLargestTextInEveryLanguage() {
        for language in ["en-GB", "en-US", "fr", "es"] {
            let app = XCUIApplication()
            app.launchArguments = ["-finn-ui-demo", "-AppleLanguages", "(\(language))",
                                   "-UIPreferredContentSizeCategoryName",
                                   "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
            app.selectTab("Coach")
            let field = app.textViews["coach.field"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            dismissKeyboardIntroduction(in: app)
            field.typeText("Set 1?")
            XCTAssertEqual(
                field.value as? String,
                "Set 1?",
                "Typing must preserve every character: \(language)"
            )
            let send = app.buttons["coach.send"]
            XCTAssertTrue(send.isHittable, language)
            let answers = app.descendants(matching: .any).matching(identifier: "coach.answer.fallback")
            let expectedCount = answers.count + 1
            send.tap()
            let replied = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "count == %d", expectedCount),
                object: answers
            )
            let outcome = XCTWaiter().wait(for: [replied], timeout: 8)
            if outcome != .completed {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Coach composer failure — \(language)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            XCTAssertEqual(outcome, .completed, "\(language): \(app.debugDescription)")
            // At accessibility sizes Send dismisses the keyboard to leave room for the reply.
            // The composer must reopen it so the next question remains reachable.
            field.tap()
            XCTAssertTrue(app.buttons["coach.dismissKeyboard"].isHittable, language)
            app.buttons["coach.dismissKeyboard"].tap()
            app.terminate()
        }
    }

    @MainActor
    func testNativeAppleIntelligenceCoachAfterRecordedDemoSet() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FINN_NATIVE_COACH_TESTS"] == "1",
            "Set TEST_RUNNER_FINN_NATIVE_COACH_TESTS=1 for real Apple Intelligence."
        )
        let app = XCUIApplication()
        // Only the camera feed is synthetic. The Coach uses the production on-device engine.
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-native-coach", "-AppleLanguages", "(en-GB)"]
        app.launch()
        app.selectTab("Coach")
        app.buttons["coach.engine"].tap()
        let modelAvailable = app.staticTexts[
            "Apple Intelligence chose the sets; the details come from Finn's records."
        ]
        .waitForExistence(timeout: 5)
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
        let counted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", "0"),
            object: reps
        )
        XCTAssertEqual(XCTWaiter().wait(for: [counted], timeout: 10), .completed)
        app.buttons["Stop set"].tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 5))
        app.buttons["result.done"].tap()
        XCTAssertTrue(app.buttons["Start a set"].waitForExistence(timeout: 5))
        app.selectTab("Coach")
        let field = app.textViews["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardIntroduction(in: app)
        field.typeText("How many reps did I do in set 1?")
        let answers = app.descendants(matching: .any).matching(identifier: "coach.answer.onDevice")
        let expectedCount = answers.count + 1
        app.buttons["coach.send"].tap()
        let answered = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == %d", expectedCount),
            object: answers
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [answered], timeout: 35),
            .completed,
            "Expected a real on-device answer, not a fallback. \(app.debugDescription)"
        )
        XCTAssertEqual(app.state, .runningForeground)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native Apple Intelligence Coach"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
