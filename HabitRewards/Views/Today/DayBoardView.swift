import Foundation
import SwiftData
import SwiftUI

/// Live totals and the habit rows for one child on one day. Tapping a row cycles its status.
struct DayBoardView: View {
    let child: Child
    let day: Date
    let navigation: DayNavigation

    @Environment(\.modelContext) private var context
    @Environment(ParentLock.self) private var parentLock
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var savedRules: [MonthRules]
    /// Every child's entries for the shown month; `DayBoard` narrows them down.
    @Query private var monthEntries: [DayEntry]

    @State private var lastTap: HabitTap?
    @State private var saveFailed = false

    init(child: Child, day: Date, navigation: DayNavigation) {
        self.child = child
        self.day = day
        self.navigation = navigation
        let month = navigation.calendar.monthInterval(containing: day)
        let start = month.start
        let end = month.end
        _monthEntries = Query(filter: #Predicate<DayEntry> { $0.date >= start && $0.date < end })
    }

    var body: some View {
        let board = makeBoard()
        VStack(spacing: 12) {
            TotalsHeader(
                dayTitle: navigation.dayTitle(day), dayPence: board.dayPence,
                monthTitle: navigation.monthTitle(day), monthPence: board.monthPence
            )
            .padding(.bottom, 8)

            if navigation.isInEarlierMonth(day) {
                EarlierMonthBanner()
            }

            ForEach(board.rows) { row in
                HabitRowButton(habit: row.habit, status: row.status) { tap(row) }
            }
        }
        .habitTapFeedback(lastTap, saveFailed: $saveFailed)
    }

    private func makeBoard() -> DayBoard {
        let rules = MonthRules.rules(for: CalendarMonth(containing: day, calendar: navigation.calendar), from: savedRules)
        return DayBoard(child: child, day: day, habits: habits, entries: monthEntries, rules: rules, calendar: navigation.calendar)
    }

    private func tap(_ row: DayBoard.Row) {
        let status = row.status.next
        parentLock.allowChange(to: day, navigation: navigation) {
            do {
                try context.saveStatus(status, child: child, habit: row.habit, day: day, calendar: navigation.calendar)
                lastTap = HabitTap(status: status)
            } catch {
                saveFailed = true
            }
        }
    }
}
