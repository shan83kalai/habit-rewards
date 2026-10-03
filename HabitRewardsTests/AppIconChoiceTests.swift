import XCTest
@testable import HabitRewards

final class AppIconChoiceTests: XCTestCase {
    func testTheStarIsTheMainIcon() {
        XCTAssertNil(AppIconChoice.star.iconName)
        XCTAssertEqual(AppIconChoice(iconName: nil), .star)
    }

    func testAlternatesRoundTripByName() {
        XCTAssertEqual(AppIconChoice.gbp.iconName, "AppIcon-GBP")
        for choice in AppIconChoice.allCases {
            XCTAssertEqual(AppIconChoice(iconName: choice.iconName), choice)
        }
        // An icon from a later version this one doesn't know about.
        XCTAssertEqual(AppIconChoice(iconName: "AppIcon-XYZ"), .star)
    }

    func testSuggestsTheCoinForThePhonesCurrency() {
        XCTAssertEqual(AppIconChoice.matching(currencyCode: "GBP"), .gbp)
        XCTAssertEqual(AppIconChoice.matching(currencyCode: "INR"), .inr)
        XCTAssertNil(AppIconChoice.matching(currencyCode: "AUD"))
    }

    func testEveryIconHasAPreviewInTheApp() {
        for choice in AppIconChoice.allCases {
            XCTAssertNotNil(UIImage(named: choice.previewImage), choice.previewImage)
        }
    }
}
