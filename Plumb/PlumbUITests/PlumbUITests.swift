//
//  PlumbUITests.swift
//  PlumbUITests
//
//  Created by James Alexander Durup on 06/10/2026.
//

import XCTest

final class PlumbUITests: XCTestCase {

    override func setUpWithError() throws {
        // runs before each test

        // one failure is enough: stop rather than carry on
        continueAfterFailure = false

        // set any starting state here — interface orientation most of all — before the tests run
    }

    override func tearDownWithError() throws {
        // runs after each test
    }

    @MainActor
    func testExample() throws {
        // UI tests launch the app under test
        let app = XCUIApplication()
        app.launch()

        // check the results with XCTAssert, as anywhere else
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
