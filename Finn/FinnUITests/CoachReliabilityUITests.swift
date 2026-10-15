import XCTest

final class CoachReliabilityUITests: XCTestCase {
    /// The simulator cannot prove live Apple Intelligence inference. This checks the complete
    /// conversation path when the model is unavailable, including returning to the tab.
    @MainActor
    func testCoachAnswersWithoutAModelAndSurvivesTabChanges() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-AppleLanguages", "(en-GB)"]
        app.launch()
        app.selectTab("Coach")

        let field = app.textFields["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
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
        field.typeText("What should I improve?")
        app.buttons["coach.send"].tap()
        let secondAnswer = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 2"), object: answer)
        XCTAssertEqual(XCTWaiter().wait(for: [secondAnswer], timeout: 5), .completed)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
