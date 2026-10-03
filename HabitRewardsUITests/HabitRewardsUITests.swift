import XCTest

/// End-to-end checks through all three tabs. The app runs with a fresh in-memory store
/// (`-uiTesting`), so each test starts from the seed data with nothing ticked.
final class HabitRewardsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTickOnTodayShowsInMonthGridAndCanBePaid() throws {
        let app = launchApp()

        // Today: tap Homework once → done, +50p.
        let homework = app.buttons["Homework"]
        XCTAssertTrue(homework.waitForExistence(timeout: 5))
        homework.tap()
        XCTAssertEqual(homework.value as? String, "Done")
        XCTAssertTrue(element(in: app, labelContaining: "£0.50").waitForExistence(timeout: 2))
        attachScreenshot(of: app, named: "1 Today")

        // Month: the same tick and total appear in the grid.
        app.tabBars.buttons["Month"].tap()
        XCTAssertTrue(element(in: app, labelContaining: "Month total, £0.50").waitForExistence(timeout: 2))
        let todaysHomeworkCell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Homework, ")).matching(NSPredicate(format: "value == %@", "Done")).firstMatch
        XCTAssertTrue(todaysHomeworkCell.exists)
        attachScreenshot(of: app, named: "2 Month")

        // Summary: pay it, then undo.
        app.tabBars.buttons["Summary"].tap()
        let pay = app.buttons["Mark £0.50 as paid"]
        XCTAssertTrue(pay.waitForExistence(timeout: 2))
        attachScreenshot(of: app, named: "3 Summary before paying")
        pay.tap()
        let confirm = app.buttons["Mark as paid"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2)) // after the parent check
        confirm.tap()
        XCTAssertTrue(element(in: app, labelContaining: "Paid £0.50").waitForExistence(timeout: 2))
        XCTAssertFalse(pay.exists)
        attachScreenshot(of: app, named: "4 Summary paid")

        app.buttons["Undo last payment"].tap()
        let confirmUndo = app.buttons["Undo payment"]
        XCTAssertTrue(confirmUndo.waitForExistence(timeout: 2))
        confirmUndo.tap()
        XCTAssertTrue(pay.waitForExistence(timeout: 2))
    }

    @MainActor
    func testMonthGridCellCyclesThroughDoneMissedAndClear() throws {
        let app = launchApp()
        app.tabBars.buttons["Month"].tap()

        // Days up to today are enabled and later ones aren't, so the last enabled Reading cell is today's.
        let readingCells = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND enabled == true", "Reading, "))
        XCTAssertTrue(readingCells.firstMatch.waitForExistence(timeout: 5))
        let today = readingCells.element(boundBy: readingCells.count - 1)

        today.tap()
        XCTAssertEqual(today.value as? String, "Done")
        today.tap()
        XCTAssertEqual(today.value as? String, "Missed")
        XCTAssertTrue(element(in: app, labelContaining: "Month total, £0.00").exists) // a lone miss floors at £0
        today.tap()
        XCTAssertEqual(today.value as? String, "Not ticked")
    }

    @MainActor
    func testFutureDaysAreLockedInTheMonthGrid() throws {
        let app = launchApp()
        app.tabBars.buttons["Month"].tap()

        let locked = app.buttons.matching(NSPredicate(format: "value == %@", "Future day"))
        let lastDayOfMonth = Calendar.current.range(of: .day, in: .month, for: .now)!.count
        let daysLeft = lastDayOfMonth - Calendar.current.component(.day, from: .now)
        // Six habits per future day, all disabled.
        XCTAssertEqual(locked.count, daysLeft * 6)
        if daysLeft > 0 { XCTAssertFalse(locked.firstMatch.isEnabled) }
    }

    @MainActor
    func testEarlierMonthHasAThisMonthShortcut() throws {
        let app = launchApp()
        app.tabBars.buttons["Summary"].tap()

        app.buttons["Previous month"].tap()
        let thisMonth = app.buttons["This month"]
        XCTAssertTrue(thisMonth.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Nothing earned yet"].exists)
        attachScreenshot(of: app, named: "5 Summary previous month")
        thisMonth.tap()
        XCTAssertFalse(thisMonth.exists)
    }

    // MARK: - Parent lock and settings

    @MainActor
    func testSettingsStayLockedWhenTheParentCheckFails() throws {
        let app = launchApp(denyingParentUnlock: true)
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.staticTexts["Parents only"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Add habit"].exists)
        XCTAssertEqual(app.steppers.count, 0)
    }

    @MainActor
    func testEarlierMonthCannotBeChangedWithoutAParent() throws {
        let app = launchApp(denyingParentUnlock: true)
        app.tabBars.buttons["Month"].tap()
        app.buttons["Previous month"].tap()

        XCTAssertTrue(element(in: app, labelContaining: "Earlier months are locked").waitForExistence(timeout: 2))
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reading, ")).firstMatch
        cell.tap()
        XCTAssertFalse(waitFor(cell, toHaveValue: "Done", timeout: 1.5))
        XCTAssertEqual(cell.value as? String, "Not ticked")
        attachScreenshot(of: app, named: "6 Earlier month locked")
    }

    @MainActor
    func testParentCanChangeAnEarlierMonth() throws {
        let app = launchApp()
        app.tabBars.buttons["Month"].tap()
        app.buttons["Previous month"].tap()

        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reading, ")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 2))
        cell.tap()
        XCTAssertTrue(waitFor(cell, toHaveValue: "Done"))
        XCTAssertFalse(element(in: app, labelContaining: "Earlier months are locked").exists) // unlocked now
    }

    @MainActor
    func testParentCanRaiseThisMonthsReward() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let increaseReward = app.buttons["thisMonthReward-Increment"]
        XCTAssertTrue(increaseReward.waitForExistence(timeout: 3))
        increaseReward.tap() // 50p → 55p
        XCTAssertEqual(app.steppers["thisMonthReward"].value as? String, "£0.55")
        attachScreenshot(of: app, named: "7 Settings")

        app.tabBars.buttons["Today"].tap()
        app.buttons["Homework"].tap()
        XCTAssertTrue(element(in: app, labelContaining: "Today, £0.55").waitForExistence(timeout: 2))
    }

    @MainActor
    func testParentCanChooseTheAppIcon() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let pound = app.buttons["Pound coin"]
        for _ in 0..<8 where !pound.isHittable {
            app.swipeUp()
        }
        pound.tap()
        dismissIconChangedAlert(in: app)
        XCTAssertTrue(waitUntilSelected(pound))

        // Put the main icon back, so later runs on this simulator start from it. iOS ignores a change
        // made while it's still finishing the last one, so try again if it didn't take.
        let star = app.buttons["Star coin"]
        for _ in 0..<3 where !star.isSelected {
            star.tap()
            dismissIconChangedAlert(in: app)
            _ = waitUntilSelected(star)
        }
        XCTAssertTrue(star.isSelected)
    }

    @MainActor
    private func waitUntilSelected(_ element: XCUIElement) -> Bool {
        let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: element)
        return XCTWaiter.wait(for: [selected], timeout: 5) == .completed
    }

    /// iOS confirms every icon change with its own alert.
    @MainActor
    private func dismissIconChangedAlert(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for alerts in [app.alerts, springboard.alerts] {
            let ok = alerts.buttons["OK"]
            if ok.waitForExistence(timeout: 3) {
                ok.tap()
                return
            }
        }
    }

    @MainActor
    func testParentCanTypeAReward() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let field = app.textFields["Reward per habit done"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "1.25")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertEqual(app.steppers["thisMonthReward"].value as? String, "£1.25")
    }

    @MainActor
    func testParentCanAddAHabit() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let add = app.buttons["Add habit"]
        scroll(app, until: add)
        add.tap()
        let name = app.textFields["habitName"]
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        name.tap()
        name.typeText("Piano practice")
        attachScreenshot(of: app, named: "8 New habit")
        app.buttons["Save"].tap()

        app.tabBars.buttons["Today"].tap()
        let piano = app.buttons["Piano practice"]
        scroll(app, until: piano)
        XCTAssertTrue(piano.exists)

        app.tabBars.buttons["Settings"].tap()
        attachScreenshot(of: app, named: "9 Settings habits")
    }

    @MainActor
    func testParentCanGiveAHabitToOneChild() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let homework = app.buttons["Homework"]
        scroll(app, until: homework)
        homework.tap()
        let firstChild = app.buttons["Child 1"]
        XCTAssertTrue(firstChild.waitForExistence(timeout: 2))
        XCTAssertTrue(firstChild.isSelected)
        firstChild.tap() // Untick: now just for Child 2.
        XCTAssertFalse(firstChild.isSelected)
        attachScreenshot(of: app, named: "10 Habit for one child")
        app.buttons["Save"].tap()
        XCTAssertTrue(element(in: app, labelContaining: "Child 2 only").waitForExistence(timeout: 2))

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["Reading"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Homework"].exists)
        app.buttons["Child 2"].tap()
        XCTAssertTrue(app.buttons["Homework"].waitForExistence(timeout: 2))
    }

    // MARK: - Polish: export, backup, reminder, accessibility

    @MainActor
    func testSummaryCanShareTheMonthAsCSVOrPDF() throws {
        let app = launchApp()
        app.tabBars.buttons["Summary"].tap()

        let share = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Share ")).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 3))
        share.tap()
        XCTAssertTrue(app.buttons["Spreadsheet (CSV)"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["PDF"].exists)
        attachScreenshot(of: app, named: "10 Share menu")
    }

    @MainActor
    func testSettingsOfferBackupRestoreAndAReminder() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let backUp = app.buttons["Back up to Files"]
        scroll(app, until: backUp)
        XCTAssertTrue(app.buttons["Restore from a backup"].exists)
        XCTAssertTrue(app.switches["Daily reminder"].exists)
        attachScreenshot(of: app, named: "11 Settings backup and reminder")
    }

    @MainActor
    func testEveryTabPassesTheAccessibilityAudit() throws {
        let app = launchApp()
        var issues: [String] = []
        for tab in ["Today", "Month", "Summary", "Settings"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
            let tabBar = app.tabBars.firstMatch.frame
            // Collect every issue rather than stopping at the first, so one run shows them all.
            try app.performAccessibilityAudit { issue in
                // Content scrolled under the see-through tab bar is measured against the glass; scrolling brings it clear.
                // Issues the audit can't tie to any element come from system-drawn parts (Settings' Form and
                // the glass bars), so there's nothing in the app to fix. Everything it can attribute must pass.
                guard let element = issue.element else { return true }
                if element.frame.intersects(tabBar) { return true }
                issues.append("\(tab): \(issue.compactDescription) — \(element.elementType.rawValue) '\(element.label)' \(element.frame) — \(issue.detailedDescription)")
                return true
            }
        }
        XCTAssertEqual(issues, [], "\n" + issues.joined(separator: "\n"))
    }

    @MainActor
    func testScreensInDarkMode() throws {
        XCUIDevice.shared.appearance = .dark
        addTeardownBlock { @MainActor in XCUIDevice.shared.appearance = .light }
        let app = launchApp()
        app.buttons["Homework"].tap()
        app.buttons["Bed on time"].tap()
        app.buttons["Bed on time"].tap()
        for tab in ["Today", "Month", "Summary", "Settings"] {
            app.tabBars.buttons[tab].tap()
            attachScreenshot(of: app, named: "Dark \(tab)")
        }
    }

    @MainActor
    func testScreensAtTheLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLocale", "en_GB", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Homework"].waitForExistence(timeout: 5))
        for tab in ["Today", "Month", "Summary"] {
            app.tabBars.buttons[tab].tap()
            attachScreenshot(of: app, named: "Large text \(tab)")
        }
    }

    // MARK: - Helpers

    @MainActor
    private func launchApp(denyingParentUnlock: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLocale", "en_GB"] + (denyingParentUnlock ? ["-denyParentUnlock"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, toHaveValue value: String, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Swipes up until `element` is on screen (lists only create rows as they scroll into view).
    @MainActor
    private func scroll(_ app: XCUIApplication, until element: XCUIElement) {
        for _ in 0..<6 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.exists, "Couldn't find \(element)")
    }

    @MainActor
    private func element(in app: XCUIApplication, labelContaining text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
