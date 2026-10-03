import Foundation

/// The home-screen icons a parent can choose: the star coin, or a coin in their own currency.
/// Each alternate is an `AppIcon-<code>` set in the asset catalogue, listed in the
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` build setting.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case star = "STAR", gbp = "GBP", usd = "USD", eur = "EUR", inr = "INR", jpy = "JPY"

    var id: Self { self }

    /// The current icon, from `UIApplication.alternateIconName`.
    init(iconName: String?) {
        self = Self.allCases.first { $0.iconName == iconName } ?? .star
    }

    /// What to pass to `setAlternateIconName`; `nil` puts back the main icon.
    var iconName: String? {
        self == .star ? nil : "AppIcon-\(rawValue)"
    }

    /// A small copy of the icon for the picker; app icon sets can't be loaded as images.
    var previewImage: String {
        "IconPreview-\(rawValue)"
    }

    var name: String {
        switch self {
        case .star: String(localized: "Star coin")
        case .gbp: String(localized: "Pound coin")
        case .usd: String(localized: "Dollar coin")
        case .eur: String(localized: "Euro coin")
        case .inr: String(localized: "Rupee coin")
        case .jpy: String(localized: "Yen coin")
        }
    }

    /// The coin matching the phone's currency, to suggest it.
    static func matching(currencyCode: String) -> AppIconChoice? {
        Self(rawValue: currencyCode)
    }
}
