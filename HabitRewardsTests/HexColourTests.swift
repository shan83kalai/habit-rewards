import XCTest
@testable import HabitRewards

final class HexColourTests: XCTestCase {
    func testParsesHashPrefixedHex() {
        let colour = HexColour("#7B61FF")
        XCTAssertEqual(colour?.red, 123.0 / 255)
        XCTAssertEqual(colour?.green, 97.0 / 255)
        XCTAssertEqual(colour?.blue, 1)
    }

    func testHashIsOptional() {
        XCTAssertEqual(HexColour("FF8A3D"), HexColour("#FF8A3D"))
    }

    func testRejectsMalformedHex() {
        XCTAssertNil(HexColour(""))
        XCTAssertNil(HexColour("#FFF"))
        XCTAssertNil(HexColour("#GG0000"))
        XCTAssertNil(HexColour("#+12345"))
        XCTAssertNil(HexColour("#7B61FF00"))
    }
}
