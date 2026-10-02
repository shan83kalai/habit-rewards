import Foundation

/// A calendar month, e.g. October 2026. Month arithmetic is plain Gregorian year/month maths.
nonisolated struct CalendarMonth: Hashable, Comparable, Sendable {
    let year: Int
    /// 1...12
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(containing date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 1)
    }

    var previous: CalendarMonth {
        month == 1 ? CalendarMonth(year: year - 1, month: 12) : CalendarMonth(year: year, month: month - 1)
    }

    var next: CalendarMonth {
        month == 12 ? CalendarMonth(year: year + 1, month: 1) : CalendarMonth(year: year, month: month + 1)
    }

    func firstDay(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    /// From the first of this month to the first of the next.
    func interval(in calendar: Calendar) -> DateInterval {
        DateInterval(start: firstDay(in: calendar), end: next.firstDay(in: calendar))
    }

    /// The start of every day in the month, in order.
    func days(in calendar: Calendar) -> [Date] {
        let first = firstDay(in: calendar)
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 0
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: first).map(calendar.startOfDay(for:))
        }
    }

    static func < (lhs: CalendarMonth, rhs: CalendarMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
