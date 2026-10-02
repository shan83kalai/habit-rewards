import SwiftUI

/// An sRGB colour parsed from `"#RRGGBB"` (the `#` is optional).
nonisolated struct HexColour: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init?(_ hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }
}

extension Color {
    /// Falls back to the accent colour if `hex` isn't valid.
    init(hex: String) {
        if let colour = HexColour(hex) {
            self.init(red: colour.red, green: colour.green, blue: colour.blue)
        } else {
            self = .accentColor
        }
    }
}
