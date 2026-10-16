import XCTest

/// the end of the onboarding on both paths: the coach question, the plan summary, then the plan
/// offer, paid (About You, then Home) or skipped (Home, with the free workout offered over it).
/// With `TEST_RUNNER_FINN_CAPTURE_DIR` set, each step is also saved as a PNG
final class OnboardingFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Pay with Apple Pay hands over to the App Store: the offer waits for the purchase (or says it
    /// is unavailable when StoreKit finds no product) and nothing moves on by itself
    @MainActor
    func testPayGoesThroughTheAppStore() throws {
        let app = try walkToPlanOffer(coach: nil)
        app.buttons["plan.weekly"].tap()
        app.buttons["plan.continue"].tap()
        let skip = app.buttons["plan.skip"]
        let handedOver = expectation(for: NSPredicate { _, _ in
            app.alerts["Purchase unavailable"].exists || !skip.isEnabled
        }, evaluatedWith: nil)
        wait(for: [handedOver], timeout: 10)
        Thread.sleep(forTimeInterval: 3)
        save("flow-35-app-store")
        XCTAssertFalse(app.buttons["aboutYou.access"].exists)
    }

    @MainActor
    func testPayingOpensAboutYouThenHome() throws {
        let app = try walkToPlanOffer(coach: nil, extraArguments: ["-finn-ui-demo-purchase"])
        app.buttons["plan.annual"].tap()
        let pay = app.buttons["plan.continue"]
        XCTAssertTrue(pay.waitForExistence(timeout: 3))
        XCTAssertEqual(pay.label, "Pay with Apple Pay")
        save("flow-30-plan-selected")
        pay.tap()
        let access = app.buttons["aboutYou.access"]
        XCTAssertTrue(access.waitForExistence(timeout: 5))
        save("flow-31-about-you")
        app.buttons["aboutYou.location"].tap()
        app.buttons["Gym"].tap()
        app.buttons["aboutYou.equipment"].tap()
        app.buttons["Dumbbells"].tap()
        app.staticTexts["A little more about you."].tap()
        for _ in 0..<6 where !access.isHittable { app.swipeUp() }
        app.buttons["aboutYou.noInjuries"].tap()
        access.tap()
        XCTAssertTrue(app.buttons["home.tryFinn"].waitForExistence(timeout: 8))
        // no offer after a purchase
        XCTAssertFalse(app.buttons["freeWorkout.accept"].waitForExistence(timeout: 2))
        save("flow-32-home")
    }

    @MainActor
    func testSkipOffersFreeWorkoutThatATapOutsideCloses() throws {
        let app = try walkToPlanOffer(coach: "Nova")
        app.buttons["plan.skip"].tap()
        let accept = app.buttons["freeWorkout.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.tryFinn"].exists)
        // the sheet's glass settles after it slides up
        Thread.sleep(forTimeInterval: 3)
        save("flow-40-free-workout-offer")
        // above the sheet, on dimmed Home
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        save("flow-41-home-after-offer")
        app.buttons["home.tryFinn"].tap()
        // the first-try flow ran: Home now shows the coach card instead of Try Finn
        XCTAssertTrue(app.buttons["home.tryFinn"].waitForNonExistence(timeout: 8))
        // the chosen coach speaks everywhere Finn's badge was
        Thread.sleep(forTimeInterval: 1)
        save("flow-42-home-coach-card")
        app.selectTab("Workout")
        let badge = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Nova, your coach")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        save("flow-43-workout")
        app.selectTab("Coach")
        XCTAssertTrue(app.descendants(matching: .any)["coach.finn"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["coach.finn"].label, "Nova, your coach")
        save("flow-44-coach")
    }

    @MainActor
    func testSkipThenAcceptOpensTheFirstTry() throws {
        let app = try walkToPlanOffer(coach: nil)
        app.buttons["plan.skip"].tap()
        let accept = app.buttons["freeWorkout.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 8))
        accept.tap()
        // the first-try flow ran: Home now shows the coach card instead of Try Finn
        XCTAssertTrue(app.buttons["home.tryFinn"].waitForNonExistence(timeout: 8))
    }

    // MARK: Steps

    /// from the welcome to the plan offer: a name, a goal and a level, the other questions
    /// skipped, then `coach` picked on the wheel (Finn when nil), and the summary.
    /// `-finn-ui-demo-purchase` makes Pay with Apple Pay stand for a verified purchase
    @MainActor
    private func walkToPlanOffer(coach: String?, extraArguments: [String] = []) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-onboarding"] + extraArguments
        app.launch()
        let welcome = app.buttons["onboarding.welcome.continue"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 8))
        welcome.tap()
        let next = app.buttons["onboarding.continue"]
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        save("flow-01-demo-no-progress")
        next.tap()
        next.tap()
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        app.typeText("Alex")
        save("flow-02-name-no-progress")
        next.tap()
        let goal = app.buttons["onboarding.goal.strength"]
        waitUntilHittable(goal)
        goal.tap()
        XCTAssertTrue(goal.isSelected)
        save("flow-03-goal-selected")
        next.tap()
        let level = app.buttons["onboarding.level.regular"]
        // Finn answers, then the next question comes by itself
        waitUntilHittable(level, timeout: 8)
        level.tap()
        next.tap()
        waitUntilHittable(app.buttons["onboarding.program.no"], timeout: 8)
        skip.tap()
        waitUntilHittable(app.buttons["onboarding.intensity.easy"])
        skip.tap()
        waitUntilHittable(app.buttons["onboarding.days.oneToTwo"])
        skip.tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        XCTAssertEqual(wheel.value as? String, "Finn")
        if let coach {
            wheel.adjust(toPickerWheelValue: coach)
            XCTAssertEqual(wheel.value as? String, coach)
        }
        Thread.sleep(forTimeInterval: 0.6)
        save("flow-10-coach")
        next.tap()
        XCTAssertTrue(app.descendants(matching: .any)["summary.loading"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        save("flow-20-loading")
        let carryOn = app.buttons["summary.continue"]
        XCTAssertTrue(carryOn.waitForExistence(timeout: 8))
        let sentence = app.staticTexts["summary.sentence"]
        XCTAssertTrue(sentence.label.contains("You want to build muscle. Right now, you're training regularly. Let's get you there by "),
                      sentence.label)
        Thread.sleep(forTimeInterval: 0.8)
        save("flow-21-summary")
        app.swipeUp()
        save("flow-22-summary-bottom")
        carryOn.tap()
        XCTAssertTrue(app.buttons["plan.skip"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plan.continue"].exists)
        save("flow-29-plan")
        return app
    }

    /// the pages beside the current one are laid out too, so wait until the element is on screen
    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let screen = XCUIApplication().frame
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if element.exists, screen.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                // the page settles after the swipe
                Thread.sleep(forTimeInterval: 0.4)
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("\(element) never came on screen")
    }

    @MainActor
    private func save(_ name: String) {
        guard let path = ProcessInfo.processInfo.environment["FINN_CAPTURE_DIR"] else { return }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appending(path: name + ".png"))
    }
}
