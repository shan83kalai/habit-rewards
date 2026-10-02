import XCTest
@testable import HabitRewards

final class MoneyTests: XCTestCase {
    private let uk = Locale(identifier: "en_GB")

    func testFormatsPenceAsPounds() {
        XCTAssertEqual(Money.format(300, currencyCode: "GBP", locale: uk), "£3.00")
        XCTAssertEqual(Money.format(175, currencyCode: "GBP", locale: uk), "£1.75")
        XCTAssertEqual(Money.format(0, currencyCode: "GBP", locale: uk), "£0.00")
        XCTAssertEqual(Money.format(5, currencyCode: "GBP", locale: uk), "£0.05")
        XCTAssertEqual(Money.format(9_300, currencyCode: "GBP", locale: uk), "£93.00")
        XCTAssertEqual(Money.format(123_456, currencyCode: "GBP", locale: uk), "£1,234.56")
    }

    func testFormatsInThePhonesOwnCurrency() {
        XCTAssertEqual(Money.format(175, currencyCode: "USD", locale: Locale(identifier: "en_US")), "$1.75")
        XCTAssertEqual(Money.format(175, currencyCode: "INR", locale: Locale(identifier: "en_IN")), "₹1.75")
        // No smaller unit than the yen, so the stored number is whole yen.
        XCTAssertEqual(Money.format(175, currencyCode: "JPY", locale: Locale(identifier: "ja_JP")), "¥175")
    }

    func testPlainAmountsForSpreadsheets() {
        XCTAssertEqual(Money.plain(0, currencyCode: "GBP"), "0.00")
        XCTAssertEqual(Money.plain(5, currencyCode: "GBP"), "0.05")
        XCTAssertEqual(Money.plain(175, currencyCode: "GBP"), "1.75")
        XCTAssertEqual(Money.plain(123_456, currencyCode: "GBP"), "1234.56")
        XCTAssertEqual(Money.plain(175, currencyCode: "JPY"), "175")
        XCTAssertEqual(Money.plain(175, currencyCode: "KWD"), "0.175")
    }

    func testTypedAmountsRoundTripToTheSmallestUnit() {
        XCTAssertEqual(Money.pence(from: Decimal(string: "1.75")!, currencyCode: "GBP"), 175)
        XCTAssertEqual(Money.pence(from: Decimal(string: "0.555")!, currencyCode: "GBP"), 56)
        XCTAssertEqual(Money.pence(from: 50, currencyCode: "JPY"), 50)
        XCTAssertEqual(Money.decimal(175, currencyCode: "GBP"), Decimal(string: "1.75"))
        XCTAssertEqual(Money.decimal(175, currencyCode: "JPY"), 175)
    }

    func testReadsTypedAmounts() {
        XCTAssertEqual(Money.pence(fromTyped: "1.25", currencyCode: "GBP", locale: uk), 125)
        XCTAssertEqual(Money.pence(fromTyped: " £1.25 ", currencyCode: "GBP", locale: uk), 125)
        XCTAssertEqual(Money.pence(fromTyped: "2", currencyCode: "GBP", locale: uk), 200)
        XCTAssertEqual(Money.pence(fromTyped: "1,25", currencyCode: "EUR", locale: Locale(identifier: "fr_FR")), 125)
        XCTAssertEqual(Money.pence(fromTyped: "500", currencyCode: "JPY", locale: Locale(identifier: "ja_JP")), 500)
        XCTAssertNil(Money.pence(fromTyped: "", currencyCode: "GBP", locale: uk))
        XCTAssertNil(Money.pence(fromTyped: "abc", currencyCode: "GBP", locale: uk))
    }

    func testEditableAmountsAreBareNumbers() {
        XCTAssertEqual(Money.editable(50, currencyCode: "GBP", locale: uk), "0.50")
        XCTAssertEqual(Money.editable(123_456, currencyCode: "GBP", locale: uk), "1234.56")
        XCTAssertEqual(Money.editable(50, currencyCode: "EUR", locale: Locale(identifier: "fr_FR")), "0,50")
        XCTAssertEqual(Money.editable(500, currencyCode: "JPY", locale: Locale(identifier: "ja_JP")), "500")
    }

    func testSymbols() {
        XCTAssertEqual(Money.symbol(currencyCode: "GBP", locale: uk), "£")
        XCTAssertEqual(Money.symbol(currencyCode: "GBP", locale: Locale(identifier: "en_US")), "£")
        XCTAssertEqual(Money.systemImage(currencyCode: "GBP"), "sterlingsign.circle")
        XCTAssertEqual(Money.systemImage(currencyCode: "XYZ"), "banknote")
    }
}
