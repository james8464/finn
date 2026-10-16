import XCTest

final class ProgressAndWorkoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        return app
    }

    @MainActor
    func testCoachPlanCanBeCompletedAndReopenedFromWorkout() {
        let app = launch()
        app.selectTab("Coach")
        app.buttons["coach.planWorkout"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.exercise."))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        waitForPlanning(app)
        XCTAssertEqual(rows.count, 4)
        for index in 0 ..< rows.count {
            let row = rows.element(boundBy: index)
            if !row.isHittable {
                app.scrollViews.firstMatch.swipeUp()
            }
            row.tap()
        }
        let validate = app.buttons["plan.validate"]
        if !validate.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(validate.isEnabled)
        validate.tap()
        app.selectTab("Workout")
        let saved = app.buttons["nextWorkout.row"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        if !saved.isHittable {
            app.scrollViews["workout.scroll"].swipeUp()
        }
        saved.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(rows.allElementsBoundByIndex.allSatisfy { $0.value as? String == "Not done" })
        XCTAssertFalse(app.buttons["plan.validate"].isEnabled)
    }

    @MainActor
    func testSuggestedWorkoutCanBeFollowedWithoutCameraAdvice() {
        let app = launch()
        openSuggestedGuide(app)
        XCTAssertTrue(app.descendants(matching: .any)["guided.animation"].exists)
        XCTAssertTrue(app.buttons["guided.advice"].exists)
        XCTAssertFalse(app.buttons["Stop set"].exists)
        let initialPrescription = app.staticTexts["guided.prescription"].label
        let next = app.buttons["guided.next"]
        app.reveal(next)
        next.tap()
        XCTAssertNotEqual(app.staticTexts["guided.prescription"].label, initialPrescription)

        // The guide may contain fewer stages after personalisation; never assume a fixed volume.
        for _ in 0..<18 {
            if app.descendants(matching: .any)["guided.complete"].exists { break }
            app.reveal(next)
            XCTAssertTrue(next.isHittable)
            next.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["guided.complete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["guided.summary"].label.contains("0 sets measured"))
        XCTAssertFalse(app.buttons["Stop set"].exists)
        app.buttons["guided.finish"].tap()
        XCTAssertTrue(app.buttons["workout.suggestedPlan"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGuidedCameraAdviceMeasuresOnlyTheChosenStage() {
        let app = launch()
        openSuggestedGuide(app)
        let prescription = app.staticTexts["guided.prescription"].label
        let advice = app.buttons["guided.advice"]
        app.reveal(advice)
        advice.tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 10))
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["6 measured reps"].waitForExistence(timeout: 8))
        // The measured result remains visible until the person explicitly continues the guide.
        XCTAssertFalse(app.buttons["guided.next"].exists)
        let resume = app.buttons["guided.resume"]
        app.reveal(resume)
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(app.staticTexts["guided.prescription"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.staticTexts["guided.prescription"].label, prescription)
    }

    @MainActor
    func testGuidedWorkoutAtLargestTextAndReducedMotionInEveryLanguage() {
        for language in ["en-GB", "en-US", "fr", "es"] {
            let app = XCUIApplication()
            app.launchArguments = ["-finn-ui-demo", "-finn-ui-reduce-motion",
                                   "-AppleLanguages", "(\(language))",
                                   "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
            openSuggestedGuide(app)
            let illustration = app.descendants(matching: .any)["guided.animation"]
            XCTAssertTrue(illustration.exists, language)
            let advice = app.buttons["guided.advice"]
            app.reveal(advice)
            XCTAssertTrue(advice.isHittable, language)
            let before = app.staticTexts["guided.prescription"].label
            let next = app.buttons["guided.next"]
            app.reveal(next)
            XCTAssertTrue(next.isHittable, language)
            next.tap()
            XCTAssertNotEqual(app.staticTexts["guided.prescription"].label, before, language)
            XCTAssertFalse(app.buttons["Stop set"].exists, "Manual progression must not activate the camera: \(language)")
            attach(app, "guided-largest-text-reduced-motion-\(language)")
            app.terminate()
        }
    }

    @MainActor
    private func openSuggestedGuide(_ app: XCUIApplication) {
        app.selectTab("Workout")
        let suggestion = app.buttons["workout.suggestedPlan"]
        app.reveal(suggestion)
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()
        let follow = app.buttons["plan.follow"]
        XCTAssertTrue(follow.waitForExistence(timeout: 5))
        waitForPlanning(app)
        follow.tap()
        XCTAssertTrue(app.staticTexts["guided.prescription"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func waitForPlanning(_ app: XCUIApplication) {
        let spinner = app.descendants(matching: .any)["plan.generating"]
        XCTAssertTrue(spinner.waitForNonExistence(timeout: 30))
        let firstRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.exercise.")).firstMatch
        wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: firstRow)], timeout: 5)
    }

    /// Home's Posture card lands on Posture even after the person left Progress on Strength
    @MainActor
    func testPostureCardAlwaysOpensThePostureSection() {
        let app = launch()
        app.selectTab("Progress")
        let section = app.segmentedControls["progress.section"]
        XCTAssertTrue(section.waitForExistence(timeout: 3))
        section.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["strength.card"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No workouts yet"].exists)
        app.selectTab("Home")
        app.buttons["home.posture"].tap()
        XCTAssertTrue(app.buttons["tab.progress"].isSelected)
        XCTAssertTrue(section.buttons.element(boundBy: 0).isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["posture.guide"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["posture.illustration"].exists)
        XCTAssertTrue(app.staticTexts["No photos yet"].exists || app
            .descendants(matching: .any)["posture.moments"].exists)
    }

    /// the Workout tab shows the next workout and history; Launch workout opens setup, and camera
    /// privacy from setup comes back to setup
    @MainActor
    func testLaunchWorkoutOpensSetupBeforeTheCamera() {
        let app = launch()
        app.selectTab("Workout")
        XCTAssertTrue(app.buttons["workout.suggestedPlan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Previous workouts"].exists)
        XCTAssertFalse(app.buttons["home.start"].exists)
        let launch = app.buttons["workout.launch"]
        XCTAssertTrue(launch.isHittable)
        XCTAssertLessThanOrEqual(launch.frame.maxY, app.buttons["tab.home"].frame.minY)
        launch.tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        app.buttons["home.privacy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["workout.launch"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.more"].exists)
    }

    /// at the largest text size the next-workout card grows past square and Launch workout stays
    /// reachable above the tab bar
    @MainActor
    func testWorkoutAndProgressAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.skipOnboardingIfShown()
        app.selectTab("Workout")
        XCTAssertTrue(app.buttons["workout.suggestedPlan"].waitForExistence(timeout: 5))
        let launch = app.buttons["workout.launch"]
        XCTAssertTrue(launch.isHittable)
        XCTAssertLessThanOrEqual(launch.frame.maxY, app.buttons["tab.home"].frame.minY)
        attach(app, "workout-largest-text")
        app.selectTab("Progress")
        XCTAssertTrue(app.descendants(matching: .any)["posture.guide"].waitForExistence(timeout: 5))
        attach(app, "progress-largest-text")
    }

    /// with past workouts, Strength draws a bar per workout; Project swaps in estimated bars and the
    /// sentence, and Back to history brings the measured bars back
    @MainActor
    func testStrengthProjectionAndBackToHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-progress-demo", "-finn-open", "progress"]
        app.launch()
        app.skipOnboardingIfShown()
        let section = app.segmentedControls["progress.section"]
        XCTAssertTrue(section.waitForExistence(timeout: 8))
        section.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["strength.chart"].waitForExistence(timeout: 3))
        attach(app, "strength-history")

        let project = app.buttons["strength.project"]
        XCTAssertTrue(project.waitForExistence(timeout: 3))
        project.tap()
        let sentence = app.staticTexts["strength.projection"]
        XCTAssertTrue(sentence.waitForExistence(timeout: 5))
        XCTAssertTrue(sentence.label.hasPrefix("At this pace, in 2 weeks"), sentence.label)
        XCTAssertFalse(project.isEnabled)
        let back = app.buttons["strength.history"]
        wait(
            for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isEnabled == true"),
                object: back
            )],
            timeout: 5
        )
        attach(app, "strength-projection")

        back.tap()
        XCTAssertTrue(sentence.waitForNonExistence(timeout: 5))
        // the measured bars grow back in before Project is offered again
        wait(
            for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "isEnabled == true"),
                object: project
            )],
            timeout: 5
        )
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
