import XCTest

final class SubscriptionAvailabilityUITests: XCTestCase {
    @MainActor
    func testUnavailableProductsOfferFinnFreeWithoutAPriceOrPurchaseButton() {
        let app = XCUIApplication()
        app.launchArguments = ["-finn-ui-paywall", "-finn-ui-no-storekit-products"]
        app.launch()

        XCTAssertTrue(app.buttons["plan.continueFree"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Finn Free"].exists)
        XCTAssertFalse(app.staticTexts["Price unavailable"].exists)
        XCTAssertFalse(app.buttons["plan.continue"].exists)
        XCTAssertTrue(app.buttons["plan.weekly"].exists)
        XCTAssertTrue(app.buttons["plan.annual"].exists)
        XCTAssertFalse(app.buttons["plan.weekly"].isEnabled)
        XCTAssertFalse(app.buttons["plan.annual"].isEnabled)
    }
}
