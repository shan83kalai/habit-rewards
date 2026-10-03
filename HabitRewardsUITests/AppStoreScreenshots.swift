import XCTest

/// The App Store screenshots, from a demo family. Skipped in normal runs. To make them, run this test
/// alone on a 6.9-inch iPhone simulator with `TEST_RUNNER_SCREENSHOTS=1`, then export the attachments.
final class AppStoreScreenshots: XCTestCase {
    @MainActor
    func testAppStoreScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] == "1", "Only when making App Store screenshots")
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)"]
        app.launch()

        XCTAssertTrue(app.buttons["Homework"].waitForExistence(timeout: 5))
        snap("1 Today")

        // Further down Today: Maya's extra task.
        app.swipeUp()
        XCTAssertTrue(app.buttons["Add extra task"].waitForExistence(timeout: 2))
        snap("2 Extra tasks")

        app.tabBars.buttons["Month"].tap()
        app.buttons["Previous month"].tap()
        snap("3 Month")

        app.tabBars.buttons["Summary"].tap()
        snap("4 Summary")

        app.tabBars.buttons["Settings"].tap()
        snap("5 Settings")

        // The habit that's just Maya's, open in the editor to show who it's for.
        let tidyRoom = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Tidy room")).firstMatch
        for _ in 0..<4 where !tidyRoom.isHittable {
            app.swipeUp()
        }
        tidyRoom.tap()
        XCTAssertTrue(app.navigationBars["Edit habit"].waitForExistence(timeout: 3))
        snap("6 Habit for some children")
    }

    @MainActor
    private func snap(_ name: String) {
        // Let the tab switch finish animating.
        Thread.sleep(forTimeInterval: 1.5)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
