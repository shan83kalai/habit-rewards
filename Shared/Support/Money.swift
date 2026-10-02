import Foundation
import os

/// Turns an integer amount in the currency's smallest unit (pence, cents; whole yen) into text,
/// in the phone's own currency. Only views and exports should call this.
///
/// Stored amounts are plain integers, so `175` is £1.75 in the UK, $1.75 in the US and ¥175 in
/// Japan, where there's no smaller unit. The code calls them "pence" throughout.
nonisolated enum Money {
    /// The phone's currency, from its region in Settings → General → Language & Region.
    /// Pounds if the region has none.
    static var currencyCode: String { Locale.current.currency?.identifier ?? "GBP" }

    /// `175` → `"£1.75"` in the UK, `"$1.75"` in the US, `"¥175"` in Japan.
    static func format(_ pence: Int, currencyCode: String = currencyCode, locale: Locale = .current) -> String {
        decimal(pence, currencyCode: currencyCode).formatted(.currency(code: currencyCode).locale(locale))
    }

    /// For spreadsheets, without a symbol or grouping: `175` → `"1.75"`; for yen, `"175"`.
    static func plain(_ pence: Int, currencyCode: String = currencyCode) -> String {
        let digits = fractionDigits(for: currencyCode)
        return decimal(pence, currencyCode: currencyCode)
            .formatted(.number.precision(.fractionLength(digits)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }

    /// `"£"`, `"$"`, `"₹"`: for column headings.
    static func symbol(currencyCode: String = currencyCode, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol
    }

    /// The SF Symbol for money in this currency: a £, $, € … coin, or a banknote for the rest.
    static func systemImage(currencyCode: String = currencyCode) -> String {
        switch currencyCode {
        case "GBP": "sterlingsign.circle"
        case "EUR": "eurosign.circle"
        case "USD", "AUD", "CAD", "NZD", "SGD", "HKD": "dollarsign.circle"
        case "INR": "indianrupeesign.circle"
        case "JPY", "CNY": "yensign.circle"
        case "KRW": "wonsign.circle"
        default: "banknote"
        }
    }

    /// The amount in whole units: `175` pence → `1.75` pounds.
    static func decimal(_ pence: Int, currencyCode: String = currencyCode) -> Decimal {
        Decimal(pence) / pow(10, fractionDigits(for: currencyCode))
    }

    /// Back to the smallest unit, to the nearest one: `1.75` pounds → `175`.
    static func pence(from amount: Decimal, currencyCode: String = currencyCode) -> Int {
        var scaled = amount * pow(10, fractionDigits(for: currencyCode))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// What a parent typed, in the smallest unit: `"1.25"` or `"£1.25"` → `125`, and `"1,25"` in
    /// France. `nil` if it isn't an amount.
    static func pence(fromTyped text: String, currencyCode: String = currencyCode, locale: Locale = .current) -> Int? {
        let text = text.trimmingCharacters(in: .whitespaces)
        let currency = Decimal.FormatStyle.Currency(code: currencyCode, locale: locale)
        let number = Decimal.FormatStyle(locale: locale)
        guard let amount = (try? currency.parseStrategy.parse(text)) ?? (try? number.parseStrategy.parse(text)) else {
            return nil
        }
        return pence(from: amount, currencyCode: currencyCode)
    }

    /// The amount as a bare number to edit: `"0.50"`, or `"0,50"` in France.
    static func editable(_ pence: Int, currencyCode: String = currencyCode, locale: Locale = .current) -> String {
        decimal(pence, currencyCode: currencyCode)
            .formatted(.number.precision(.fractionLength(fractionDigits(for: currencyCode))).grouping(.never).locale(locale))
    }

    /// Digits after the decimal point, as the system formats the currency: 2 for pounds,
    /// 0 for yen, 3 for Kuwaiti dinars.
    static func fractionDigits(for currencyCode: String) -> Int {
        digitsCache.withLock { cache in
            if let digits = cache[currencyCode] { return digits }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            cache[currencyCode] = formatter.maximumFractionDigits
            return formatter.maximumFractionDigits
        }
    }

    private static let digitsCache = OSAllocatedUnfairLock(initialState: [String: Int]())
}
