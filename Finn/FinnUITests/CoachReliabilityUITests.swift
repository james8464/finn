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

    /// no Done button: touching a message in the conversation puts the keyboard away
    @MainActor
    private func putKeyboardAway(in app: XCUIApplication) -> Bool {
        let messages = app.scrollViews["coach.transcript"].descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@ OR identifier BEGINSWITH %@", ["coach.question", "coach.opening"], "coach.answer."
        ))
        guard let message = messages.allElementsBoundByIndex.last(where: \.isHittable) else {
            return false
        }
        message.tap()
        return app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
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
            format: "label CONTAINS %@", "Choose one in the Workout tab"
        ))
        XCTAssertTrue(answer.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(putKeyboardAway(in: app))
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

    /// the conversation with Finn is still there after the app is closed and reopened
    @MainActor
    func testConversationSurvivesARelaunch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-finn-ui-demo", "-AppleLanguages", "(en-GB)", "-finn-ui-demo-suite", "FinnCoachRelaunch-\(UUID().uuidString)",
        ]
        app.launch()
        app.selectTab("Coach")
        let field = app.textViews["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardIntroduction(in: app)
        field.typeText("Remember this, Finn\n")
        let question = app.staticTexts["Remember this, Finn"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        let reply = app.descendants(matching: .any).matching(identifier: "coach.answer.fallback").firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.selectTab("Coach")
        XCTAssertTrue(question.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(reply.waitForExistence(timeout: 5), app.debugDescription)
    }

    /// the thread reads like a messaging app: the day above each day's first message, a thin
    /// line after a pause, the time on every message. Seeds three days of messages through the
    /// defaults' argument domain
    @MainActor
    func testThreadShowsDaysTimesAndPauses() throws {
        let calendar = Calendar.current
        let now = Date.now
        func at(daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0,
                          of: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)!
        }
        let thread: [(String, String, Date)] = [
            ("person", "Je reprends le sport cette semaine, tu m'aides ?", at(daysAgo: 2, 18, 5)),
            ("coach", "Avec plaisir. On commence doucement : trois séances courtes cette semaine.", at(daysAgo: 2, 18, 5)),
            ("person", "Je fais quoi ce matin ?", at(daysAgo: 1, 8, 10)),
            ("coach", "Deux séries de 10 squats, puis deux séries de 8 pompes, une minute de repos entre chaque.", at(daysAgo: 1, 8, 10)),
            ("person", "C'est fait !", at(daysAgo: 1, 8, 31)),
            ("coach", "Bravo. Étire tes cuisses deux minutes et bois un grand verre d'eau.", at(daysAgo: 1, 8, 31)),
            ("person", "J'ai un peu de courbatures ce soir", at(daysAgo: 1, 19, 40)),
            ("coach", "C'est normal après une reprise. Marche vingt minutes demain et garde les squats pour après-demain.", at(daysAgo: 1, 19, 41)),
            ("person", "Salut coach, je suis prêt pour aujourd'hui", now.addingTimeInterval(-60)),
            ("coach", "Parfait. Trois séries de 12 squats, puis 3 séries de 10 pompes. Garde le dos droit.", now.addingTimeInterval(-55)),
        ]
        let messages: [[String: Any]] = thread.map { role, text, date in
            var message: [String: Any] = ["id": UUID().uuidString, "role": role, "text": text,
                                          "sentAt": date.timeIntervalSinceReferenceDate]
            if role == "coach" { message["engine"] = "onDevice" }
            return message
        }
        let data = try JSONSerialization.data(withJSONObject: messages)
        let app = XCUIApplication()
        app.launchArguments = [
            "-finn-ui-demo", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
            "-coachConversation.v1", "<" + data.map { String(format: "%02x", $0) }.joined() + ">",
        ]
        app.launch()
        app.selectTab("Coach")
        let days = app.staticTexts.matching(identifier: "coach.day")
        XCTAssertTrue(days.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Hier"].exists, app.debugDescription)
        XCTAssertTrue(days.matching(NSPredicate(format: "label BEGINSWITH %@", "Aujourd")).firstMatch.exists)
        attachScreenshot(of: app, named: "Coach thread")
        app.scrollViews["coach.transcript"].swipeDown()
        attachScreenshot(of: app, named: "Coach thread, earlier")
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
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), language)
            XCTAssertTrue(putKeyboardAway(in: app), language)
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
            "Apple Intelligence writes the answers on this iPhone, using your saved sets."
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

    /// The coach chats like any assistant: a greeting gets a written reply from Apple Intelligence,
    /// with no saved set needed
    @MainActor
    func testNativeAppleIntelligenceCoachAnswersAGreeting() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FINN_NATIVE_COACH_TESTS"] == "1",
            "Set TEST_RUNNER_FINN_NATIVE_COACH_TESTS=1 for real Apple Intelligence."
        )
        let app = XCUIApplication()
        // onboarding answers through the defaults' argument domain: a portrait and a first name
        app.launchArguments = [
            "-finn-ui-demo", "-finn-ui-native-coach", "-AppleLanguages", "(fr)",
            "-finn.coach", "nova", "-finn.firstName", "Théo", "-finn.trainingGoal", "strength",
        ]
        app.launch()
        app.selectTab("Coach")
        let field = app.textViews["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissKeyboardIntroduction(in: app)
        field.typeText("Hey, salut coach, on peut parler ?")
        app.buttons["coach.send"].tap()
        if app.descendants(matching: .any)["coach.thinking"].waitForExistence(timeout: 3) {
            attachScreenshot(of: app, named: "Coach thinking")
        }
        let answers = app.descendants(matching: .any).matching(identifier: "coach.answer.onDevice")
        XCTAssertTrue(
            answers.firstMatch.waitForExistence(timeout: 45),
            "Expected a reply written by Apple Intelligence. \(app.debugDescription)"
        )
        XCTAssertFalse(answers.firstMatch.label.isEmpty)
        attachScreenshot(of: app, named: "Coach greeting")

        // the onboarding answers reach every turn: Finn knows the first name without being told
        field.tap()
        field.typeText("Tu te souviens de mon prénom ?")
        app.buttons["coach.send"].tap()
        let remembered = answers.matching(NSPredicate(format: "label CONTAINS %@", "Théo")).firstMatch
        XCTAssertTrue(remembered.waitForExistence(timeout: 45), app.debugDescription)
        attachScreenshot(of: app, named: "Coach remembers")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
