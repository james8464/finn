import XCTest
import UIKit

/// Captures supporting screens in both appearances and verifies controls after branch consolidation.
final class PresentationReviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSupportingPagesInBothAppearances() throws {
        for appearance in ["light", "dark"] {
            for page in ["workout", "options", "privacy", "coach", "awards", "history", "posture"] {
                let app = XCUIApplication()
                app.launchArguments = ["-finn-ui-demo", "-finn-ui-\(appearance)", "-finn-open", page]
                app.launch()
                if page == "posture" { app.selectTab("Posture") }
                XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))
                try save("\(page)-\(appearance)")
                if page == "workout" { XCTAssertTrue(app.buttons["home.start"].isHittable) }
                if page == "coach" { XCTAssertTrue(app.textFields["coach.field"].isHittable) }
                app.terminate()
            }
        }
    }

    @MainActor func testMeasuredResultChartDrawsBars() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-ui-light"]
        app.launch()
        app.openWorkoutTab()
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 8))
        app.buttons["Start set"].tap()
        let stop = app.buttons["Stop set"]
        XCTAssertTrue(stop.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 4)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Set reviewed"].waitForExistence(timeout: 8))
        let chart = app.otherElements["result.depthChart"]
        app.reveal(chart)
        try save("result-chart-visible-bars")
        XCTAssertGreaterThan(chart.frame.height, 100)
        let image = try XCTUnwrap(chart.screenshot().image.cgImage)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let pink = stride(from: 0, to: bytes.count, by: 4).filter { index in
            Int(bytes[index]) - Int(bytes[index + 1]) > 50 && bytes[index + 2] > 60
        }.count
        XCTAssertGreaterThan(pink, 40, "The highlighted measured reps must render as visible chart bars")
    }

    @MainActor func testSettingsHaveOneControlForEachPreference() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-open", "options"]
        app.launch()
        for identifier in ["options.hapticFeedback", "options.soundFeedback", "options.language"] {
            let controls = app.buttons.matching(identifier: identifier)
            app.reveal(controls.firstMatch)
            XCTAssertEqual(controls.count, 1, "Duplicate preference control: \(identifier)")
        }
    }

    @MainActor func testPrivacyDisclosuresRetainTheCameraPolicy() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-demo", "-finn-open", "privacy"]
        app.launch()
        let camera = app.buttons["privacy.camera"]
        app.reveal(camera)
        camera.tap()
        XCTAssertTrue(app.staticTexts["Video is processed on this iPhone and never saved."].waitForExistence(timeout: 3))
        try save("privacy-camera-details")
        camera.tap()
        let coach = app.buttons["privacy.coach"]
        app.reveal(coach)
        coach.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "Private Cloud Compute")).firstMatch.exists)
        coach.tap()
        app.reveal(app.links["Full privacy policy"])
        XCTAssertTrue(app.links["Full privacy policy"].isHittable)
    }

    @MainActor func testLargestTextWithReducedMotion() throws {
        for page in ["workout", "options", "privacy", "coach", "posture"] {
            let app = XCUIApplication()
            app.launchArguments = ["-finn-ui-demo", "-finn-ui-dark", "-finn-ui-reduce-motion",
                                   "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                                   "-finn-open", page]
            app.launch()
            if page == "posture" {
                app.selectTab("Posture")
                let note = app.staticTexts["Motion paused for Reduce Motion"]
                app.reveal(note)
                XCTAssertTrue(note.exists)
            }
            try save("\(page)-largest-text-reduced-motion")
            if page == "workout" { XCTAssertTrue(app.buttons["home.start"].isHittable) }
            if page == "options" { app.reveal(app.buttons["options.replayOnboarding"]) }
            if page == "privacy" { app.reveal(app.links["Full privacy policy"]) }
            if page == "coach" { XCTAssertTrue(app.textFields["coach.field"].isHittable) }
            try save("\(page)-largest-text-end")
            app.terminate()
        }
    }

    @MainActor private func save(_ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["FINN_CAPTURE_DIR"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appending(path: name + ".png"))
    }
}
