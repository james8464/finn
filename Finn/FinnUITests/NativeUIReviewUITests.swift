import XCTest
import UIKit

/// navigation regression checks, with optional screenshots for the design review
final class NativeUIReviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testNativeDestinations() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        try save("summary")
        app.selectTab("Workout")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(app.buttons["home.start"].frame.maxY, app.buttons["tab.home"].frame.minY)
        try save("workout")
        app.selectTab("Posture")
        XCTAssertTrue(app.scrollViews["posture.guide"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["posture.playback"].exists)
        try save("history-empty")
        app.selectTab("Coach")
        XCTAssertTrue(app.textFields["coach.field"].waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(app.buttons["coach.engine"].frame.height, 44)
        try save("coach")
        app.buttons["coach.engine"].tap()
        XCTAssertTrue(app.navigationBars["About Coach"].waitForExistence(timeout: 3))
        try save("coach-source")
        app.buttons["Done"].tap()
        app.selectTab("Home")
        app.buttons["home.account"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        try save("settings")
        app.buttons["Options"].tap()
        XCTAssertTrue(app.navigationBars["Options"].waitForExistence(timeout: 3))
        try save("options")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Privacy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 3))
        try save("privacy")
    }

    @MainActor
    func testDarkAppearanceAndLargestText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-dark"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        try save("summary-dark")
        let regularHomeFrame = app.buttons["tab.home"].frame
        app.openWorkoutTab()
        XCTAssertLessThanOrEqual(app.buttons["home.start"].frame.maxY, app.buttons["tab.home"].frame.minY)
        try save("workout-dark")
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        try save("summary-largest-text")
        XCTAssertGreaterThan(app.buttons["tab.home"].frame.height, regularHomeFrame.height)
        XCTAssertGreaterThan(app.buttons["tab.home"].frame.width, regularHomeFrame.width)
        try app.performAccessibilityAudit(for: [.textClipped, .hitRegion]) { issue in
            print("Largest Home: \(issue.compactDescription) \(issue.element?.debugDescription ?? "no element")")
            return false
        }
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].isHittable)
        XCTAssertLessThanOrEqual(app.buttons["home.start"].frame.maxY, app.buttons["tab.home"].frame.minY)
        try save("workout-largest-text")
        app.selectTab("Coach")
        let field = app.textFields["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("My last set")
        XCTAssertTrue(app.buttons["coach.send"].isHittable)
        try save("coach-largest-text-keyboard")
        app.buttons["coach.send"].tap()
        XCTAssertTrue(app.staticTexts["My last set"].waitForExistence(timeout: 5))
        app.buttons["coach.dismissKeyboard"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 3))
        app.selectTab("Home")
    }

    @MainActor
    func testHomeLargestTextAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.skipOnboardingIfShown()
        XCTAssertTrue(app.buttons["home.tryFinn"].waitForExistence(timeout: 8))
        try save("home-largest-text-normal")
        try app.performAccessibilityAudit(for: [.textClipped, .hitRegion]) { issue in
            print("Home without demo: \(issue.compactDescription) \(issue.element?.debugDescription ?? "no element")")
            return false
        }
    }

    @MainActor
    func testRestoredLargestTextControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.openWorkoutTab()
        XCTAssertTrue(app.buttons["home.start"].isHittable)
        XCTAssertLessThanOrEqual(app.buttons["home.start"].frame.maxY, app.buttons["tab.home"].frame.minY)
        try save("workout-largest-text")
        app.selectTab("Coach")
        let field = app.textFields["coach.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("My last set")
        XCTAssertTrue(app.buttons["coach.send"].isHittable)
        try save("coach-largest-text-keyboard")
        app.buttons["coach.dismissKeyboard"].tap()
        app.selectTab("Home")
        XCTAssertTrue(app.buttons["home.tryFinn"].exists)
        app.selectTab("Coach")
        XCTAssertEqual(field.value as? String, "My last set", "Dismissing the keyboard must preserve the draft")
    }

    @MainActor
    func testFrenchNavigationAndBestSet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["home.tryFinn"].exists)
        try save("summary-french")
        let best = app.buttons["home.weights"]
        if !best.isHittable { app.swipeUp() }
        best.tap()
        XCTAssertTrue(app.navigationBars["Meilleure série"].waitForExistence(timeout: 3))
        app.selectTab("Séance")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 3))
        try save("workout-french")
    }

    @MainActor
    func testHealthOfferAtLargestText() throws {
        for (size, name) in [("UICTContentSizeCategoryL", "health-offer"),
                             ("UICTContentSizeCategoryAccessibilityXXXL", "health-offer-largest-text")] {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-open", "health",
                               "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        XCTAssertTrue(app.buttons["offer.later"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["offer.later"].isHittable)
        XCTAssertTrue(app.buttons["offer.personalize"].isHittable)
        XCTAssertEqual(app.buttons["offer.personalize"].label, "Continue")
        assertHealthActionTextIsVisible(app.buttons["offer.personalize"])
        XCTAssertTrue(app.staticTexts["Personalize with Health"].exists)
        try save(name)
        app.scrollViews.firstMatch.swipeUp()
        try save(name + "-bottom")
        app.buttons["offer.later"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 3))
        app.terminate()
        }
    }

    @MainActor
    func testCameraPrimerActionsAtBothTextSizes() throws {
        for (size, name) in [("UICTContentSizeCategoryL", "camera-primer"),
                             ("UICTContentSizeCategoryAccessibilityXXXL", "camera-primer-largest-text")] {
            let app = XCUIApplication()
            app.launchArguments = ["-finn-ui-demo", "-finn-open", "camera-primer",
                                   "-UIPreferredContentSizeCategoryName", size]
            app.launch()
            XCTAssertTrue(app.buttons["primer.continue"].waitForExistence(timeout: 8))
            try save(name)
            XCTAssertTrue(app.buttons["primer.continue"].isHittable)
            XCTAssertTrue(app.buttons["primer.privacy"].isHittable)
            app.scrollViews.firstMatch.swipeUp()
            try save(name + "-bottom")
            app.terminate()
        }
    }

    @MainActor
    func testLargeTextLongPagesReachTheirLastControls() throws {
        let app = XCUIApplication()
        let arguments = ["-finn-ui-demo", "-UIPreferredContentSizeCategoryName",
                         "UICTContentSizeCategoryAccessibilityXXXL", "-finn-open"]
        app.launchArguments = arguments + ["privacy"]
        app.launch()
        let policy = app.links["Full privacy policy"]
        app.reveal(policy, swipes: 24)
        XCTAssertTrue(policy.isHittable)
        try save("privacy-largest-text-end")
        app.terminate()
        app.launchArguments = arguments + ["options"]
        app.launch()
        let replay = app.buttons["options.replayOnboarding"]
        app.reveal(replay, swipes: 24)
        XCTAssertTrue(replay.isHittable)
        try save("options-largest-text-end")
        let data = app.buttons["Health data"]
        for _ in 0..<12 where !data.isHittable { app.swipeDown() }
        data.tap()
        try save("health-data-largest-text")
    }

    @MainActor
    private func save(_ name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["FINN_CAPTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        // let native navigation/material transitions settle before capturing
        Thread.sleep(forTimeInterval: 2)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url.appending(path: "\(name).png"))
    }

    /// accessibility labels can exist even when a control renders white text on white
    @MainActor private func assertHealthActionTextIsVisible(_ button: XCUIElement) {
        guard let image = button.screenshot().image.cgImage else {
            XCTFail("Could not inspect the Health action's rendered label")
            return
        }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(rendered)
        // ignore the rounded corners; the centre must contain the dark, visible label
        var darkPixels = 0
        for y in (height / 5)..<(height * 4 / 5) {
            for x in (width / 5)..<(width * 4 / 5) {
                let offset = (y * width + x) * 4
                if pixels[offset] < 128 && pixels[offset + 1] < 128 && pixels[offset + 2] < 128 {
                    darkPixels += 1
                }
            }
        }
        XCTAssertGreaterThan(darkPixels, 20, "The Health action needs a visibly contrasting label")
    }
}
