from pathlib import Path
p=Path('Finn/FinnUITests/WorkoutFlowUITests.swift')
s=p.read_text(); start=s.index('        XCTAssertTrue(app.navigationBars["Privacy"].exists)',s.index('func testPrivacySummary')); end=s.index('\n    @MainActor\n    func testPrivacyScreen',start)
s=s[:start]+'''        verifyPrivacyDisclosures(app)
    }
''' + s[end:]
start=s.index('        XCTAssertTrue(app.navigationBars["Privacy"].exists)',s.index('private func auditPrivacy')); end=s.index('        // iOS 27',start)
s=s[:start]+'''        verifyPrivacyDisclosures(app)
'''+s[end:]
pos=s.index('    @MainActor\n    func testDeniedCamera')
s=s[:pos]+'''    @MainActor
    private func verifyPrivacyDisclosures(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        let sections: [(String, [String])] = [
            ("privacy.camera", ["Video is processed on this iPhone and never saved.", "Finn uses the camera to measure", "One camera view cannot assess"]),
            ("Saved results", ["Measured set summaries are saved", "Saved summaries may be included", "Delete saved sessions in History."]),
            ("Apple Health", ["If you turn on Save workouts", "Finn reads Health only", "Health keeps these workouts"]),
            ("Optional audio", ["Finn says the countdown"]),
            ("privacy.coach", ["Coach uses your question and saved set summaries."]),
            ("Optional explanation", ["On supported iPhones, Apple's on-device model"]),
        ]
        for (name, sentences) in sections {
            let disclosure = app.buttons[name]
            app.reveal(disclosure)
            disclosure.tap()
            for sentence in sentences {
                let text = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", sentence)).firstMatch
                app.reveal(text)
                XCTAssertTrue(text.exists, "Missing privacy disclosure: \\(sentence)")
            }
            for _ in 0..<8 where !disclosure.isHittable { app.swipeDown() }
            disclosure.tap()
        }
        let policy = app.links["Full privacy policy"]
        app.reveal(policy)
        XCTAssertGreaterThanOrEqual(policy.frame.height, 44)
    }

'''+s[pos:]
s=s.replace('app.buttons["Delete all data"].tap()\n        XCTAssertTrue', 'app.buttons["Delete all data"].tap()\n        app.openFromHome("History")\n        XCTAssertTrue')
s=s.replace('XCTAssertTrue(savedSession.waitForExistence(timeout: 5))','app.reveal(savedSession)')
s=s.replace('        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "rep.6").firstMatch.exists)','        app.reveal(app.descendants(matching: .any).matching(identifier: "rep.6").firstMatch)')
s=s.replace('        XCTAssertTrue(app.staticTexts["Saved sessions"].waitForExistence(timeout: 5))\n','')
s=s.replace('        delete.tap()','        app.reveal(delete)\n        delete.tap()')
p.write_text(s)
p=Path('Finn/FinnUITests/HomeNavigation.swift');s=p.read_text().replace('        item.tap()','        item.tap()\n        XCTAssertTrue(navigationBars[page].waitForExistence(timeout: 5))');p.write_text(s)
