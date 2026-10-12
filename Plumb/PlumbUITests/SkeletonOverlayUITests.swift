import XCTest

final class SkeletonOverlayUITests: XCTestCase {
    /// The Debug demo feed has hips, knees, and ankles but no picture. It checks that the
    /// skeleton and the knee angle appear during a set, not that they line up with a body.
    @MainActor
    func testDemoSetShowsTheSkeletonWithTheKneeAngle() {
        let app = XCUIApplication()
        app.launchArguments += ["-plumb-ui-demo"]
        app.launch()
        app.buttons["Set up camera"].tap()
        app.buttons["Start set"].tap()
        let skeleton = app.descendants(matching: .any)["camera.skeleton"]
        XCTAssertTrue(skeleton.waitForExistence(timeout: 8))
        let value = skeleton.value as? String ?? ""
        XCTAssertTrue(value.contains("Knee"), "skeleton value: \(value)")
        app.buttons["Stop set"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: skeleton)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed)
    }

    /// Plays a side-view squat video on the camera screen. It runs when the test runner
    /// is given a file, including the repository's synthetic exercise fixture:
    /// `TEST_RUNNER_PLUMB_VIDEO_FILE=/path/to/video.mp4 xcodebuild test …`. Vision body pose does
    /// not run on the simulator, so also pass `TEST_RUNNER_PLUMB_VIDEO_POSES`, poses recorded from
    /// the same file on a Mac. `TEST_RUNNER_PLUMB_VIDEO_SECONDS` sets the set length (default 32).
    @MainActor
    func testVideoFileSetShowsTheSkeletonAndCountsReps() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["PLUMB_VIDEO_FILE"], !path.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_PLUMB_VIDEO_FILE to a side-view squat video to run this test.")
        }
        let seconds = Double(environment["PLUMB_VIDEO_SECONDS"] ?? "") ?? 32
        let app = XCUIApplication()
        app.launchArguments += ["-plumb-video-file", path]
        if let poses = environment["PLUMB_VIDEO_POSES"], !poses.isEmpty {
            app.launchArguments += ["-plumb-video-poses", poses]
        }
        app.launch()
        app.buttons["Set up camera"].tap()
        let skeleton = app.descendants(matching: .any)["camera.skeleton"]
        XCTAssertTrue(skeleton.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot(named: "Framing with skeleton")
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 6))
        Thread.sleep(forTimeInterval: seconds / 2)
        attachScreenshot(named: "Mid-set with skeleton")
        Thread.sleep(forTimeInterval: seconds / 2)
        stop.tap()
        // Measured or refused, the result must say something.
        let outcome = app.staticTexts.matching(NSPredicate(
            format: "label ENDSWITH %@ OR label == %@", "measured reps", "Couldn’t assess this set")).firstMatch
        XCTAssertTrue(outcome.waitForExistence(timeout: 15))
        attachScreenshot(named: "Result")
        print("PLUMB_VIDEO_RESULT \(outcome.label)")
        if let expected = environment["PLUMB_VIDEO_EXPECTED_REPS"] {
            XCTAssertEqual(outcome.label, "\(expected) measured reps")
        }
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
