import Foundation

nonisolated enum RelativeDay: Sendable {
    case today
    case yesterday
    case earlier
}

/// Moving between days for catch-up entry. Every day is a start-of-day `Date`, and days
/// after today can't be reached.
nonisolated struct DayNavigation: Sendable {
    let today: Date
    let calendar: Calendar

    init(today: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        self.today = calendar.startOfDay(for: today)
    }

    func previous(_ day: Date) -> Date {
        shifted(day, by: -1)
    }

    func next(_ day: Date) -> Date {
        clamped(shifted(day, by: 1))
    }

    func canGoForward(from day: Date) -> Bool {
        calendar.startOfDay(for: day) < today
    }

    /// The start of `day`, pulled back to today if it's in the future.
    func clamped(_ day: Date) -> Date {
        min(calendar.startOfDay(for: day), today)
    }

    func relative(_ day: Date) -> RelativeDay {
        let start = calendar.startOfDay(for: day)
        if start == today { return .today }
        if start == previous(today) { return .yesterday }
        return .earlier
    }

    func isInCurrentMonth(_ day: Date) -> Bool {
        calendar.isDate(day, equalTo: today, toGranularity: .month)
    }

    var currentMonth: CalendarMonth {
        CalendarMonth(containing: today, calendar: calendar)
    }

    /// Days in months before this one are closed: changing them needs a parent.
    func isInEarlierMonth(_ day: Date) -> Bool {
        CalendarMonth(containing: day, calendar: calendar) < currentMonth
    }

    private func shifted(_ day: Date, by days: Int) -> Date {
        let start = calendar.startOfDay(for: day)
        guard let moved = calendar.date(byAdding: .day, value: days, to: start) else { return start }
        return calendar.startOfDay(for: moved)
    }
}

extension Calendar {
    /// The month containing `date`, from the first of the month to the first of the next.
    nonisolated func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 0)
    }
}
