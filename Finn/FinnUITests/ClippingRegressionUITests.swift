import XCTest

/// isolates the screens reported by the whole-app clipping survey
final class ClippingRegressionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }

    @MainActor func testAwardSheetDoesNotClipText() throws {
        try atBothTextSizes("award", arguments: ["-finn-ui-badges-demo", "-finn-open", "awards"]) { app in
            let award = app.descendants(matching: .any).matching(identifier: "badge.row").firstMatch
            XCTAssertTrue(award.waitForExistence(timeout: 8))
            award.tap()
            XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        }
    }

    @MainActor func testSettingsRowsDoNotClipText() throws {
        try atBothTextSizes("settings") { app in
            let account = app.buttons["home.account"]
            XCTAssertTrue(account.waitForExistence(timeout: 8))
            account.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        }
    }

    @MainActor func testHealthSheetDoesNotClipText() throws {
        try atBothTextSizes("health", arguments: ["-finn-open", "health"]) { app in
            XCTAssertTrue(app.buttons["offer.later"].waitForExistence(timeout: 8))
        }
    }

    @MainActor func testCameraPrimerDoesNotClipText() throws {
        try atBothTextSizes("primer", arguments: ["-finn-open", "camera-primer"]) { app in
            XCTAssertTrue(app.buttons["primer.continue"].waitForExistence(timeout: 8))
        }
    }

    @MainActor private func atBothTextSizes(
        _ name: String, arguments: [String] = [], prepare: (XCUIApplication) -> Void
    ) throws {
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = XCUIApplication()
            app.launchArguments = ["-finn-ui-demo", "-UIPreferredContentSizeCategoryName", size] + arguments
            app.launch()
            prepare(app)
            Thread.sleep(forTimeInterval: 2)
            try save("\(name)-\(size)-before")
            try app.performAccessibilityAudit(for: .textClipped) { issue in
                print("CLIPPING_REGRESSION \(name) \(size): \(issue.detailedDescription) \(issue.element?.debugDescription ?? "no element")")
                XCTFail("\(name) \(size): \(issue.compactDescription)")
                return true
            }
            try save("\(name)-\(size)-after")
            app.terminate()
        }
    }

    private func save(_ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["FINN_CAPTURE_DIR"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appending(path: name + ".png"))
    }
}
