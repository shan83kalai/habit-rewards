import Foundation

/// A month for every child, flattened to plain values for export. Built on the main actor from
/// `MonthSheet`s, then safe to hand to share-sheet code running anywhere.
nonisolated struct MonthReport: Sendable, Equatable {
    struct HabitLine: Sendable, Equatable {
        let title: String
        /// One per day of the month.
        let statuses: [HabitStatus]
    }

    struct ChildPage: Sendable, Equatable {
        let name: String
        let habits: [HabitLine]
        /// `nil` for days after today.
        let dayScores: [Int?]
        let runningTotals: [Int?]
        let totalPence: Int
        let perfectDays: Int
        let bestStreak: Int
    }

    /// e.g. "October 2026"
    let title: String
    let dayNumbers: [Int]
    let children: [ChildPage]
    /// The phone's currency when the report was made, e.g. "GBP".
    let currencyCode: String
}

extension MonthReport {
    init(title: String, sheets: [(name: String, sheet: MonthSheet)], currencyCode: String = Money.currencyCode) {
        self.title = title
        self.currencyCode = currencyCode
        self.dayNumbers = Array(1...max(1, sheets.first?.sheet.days.count ?? 1))
        self.children = sheets.map { name, sheet in
            ChildPage(
                name: name,
                habits: sheet.rows.map { HabitLine(title: $0.habit.title, statuses: $0.statuses) },
                dayScores: sheet.dayScores,
                runningTotals: sheet.runningTotals,
                totalPence: sheet.total,
                perfectDays: sheet.perfectDays,
                bestStreak: sheet.bestStreak
            )
        }
    }
}

// MARK: - CSV

extension MonthReport {
    /// The month laid out like the spreadsheet: a block per child with habits as rows and days
    /// as columns, then the day-score and running-total rows. Money is a plain number ("1.75").
    nonisolated var csv: String {
        var rows: [[String]] = [["Habit Rewards", title]]
        for child in children {
            rows.append([])
            rows.append([child.name])
            rows.append(["Habit"] + dayNumbers.map(String.init))
            for habit in child.habits {
                rows.append([habit.title] + habit.statuses.map(Self.csvSymbol))
            }
            rows.append(["Day score (\(currencySymbol))"] + child.dayScores.map { $0.map(csvMoney) ?? "" })
            rows.append(["Running total (\(currencySymbol))"] + child.runningTotals.map { $0.map(csvMoney) ?? "" })
            rows.append(["Month total (\(currencySymbol))", csvMoney(child.totalPence)])
            rows.append(["Perfect days", String(child.perfectDays)])
            rows.append(["Best streak (days)", String(child.bestStreak)])
        }
        return rows.map { $0.map(Self.csvField).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// UTF-8 with a byte-order mark, so Excel shows ✓, ✗ and currency symbols correctly.
    nonisolated var csvData: Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(csv.utf8)
    }

    /// Quotes a field if it contains a comma, quote or line break (RFC 4180).
    nonisolated static func csvField(_ text: String) -> String {
        guard text.contains(where: { ",\"\n\r".contains($0) }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// `175` → `"1.75"` (or `"175"` for yen)
    nonisolated func csvMoney(_ pence: Int) -> String {
        Money.plain(pence, currencyCode: currencyCode)
    }

    /// "£", "$", "₹": for the money rows' headings.
    nonisolated var currencySymbol: String {
        Money.symbol(currencyCode: currencyCode)
    }

    nonisolated private static func csvSymbol(_ status: HabitStatus) -> String {
        switch status {
        case .unset: ""
        case .done: "✓"
        case .missed: "✗"
        }
    }
}
