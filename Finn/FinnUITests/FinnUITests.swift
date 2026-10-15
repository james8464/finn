//
//  FinnUITests.swift
//  FinnUITests
//
//  Created by James Alexander Durup on 06/10/2026.
//

import XCTest

final class FinnUITests: XCTestCase {

    override func setUpWithError() throws {
        // put setup code here. This method is called before the invocation of each test method in the class.

        // in UI tests it's usually best to stop immediately when a failure occurs
        continueAfterFailure = false

        // in UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test
        let app = XCUIApplication()
        app.launch()

        // use XCTAssert and related functions to verify your tests produce the correct results
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        // this measures how long it takes to launch your application
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
