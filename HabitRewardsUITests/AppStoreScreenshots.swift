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

        app.tabBars.buttons["Month"].tap()
        app.buttons["Previous month"].tap()
        snap("2 Month")

        app.tabBars.buttons["Summary"].tap()
        snap("3 Summary")

        app.tabBars.buttons["Settings"].tap()
        snap("4 Settings")
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
