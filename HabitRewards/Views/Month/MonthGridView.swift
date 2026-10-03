import Foundation
import SwiftData
import SwiftUI

/// Month total, perfect days and the grid for one child. Tapping a cell cycles its status.
struct MonthGridView: View {
    let child: Child
    let month: CalendarMonth
    let navigation: DayNavigation

    @Environment(\.modelContext) private var context
    @Environment(ParentLock.self) private var parentLock
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var savedRules: [MonthRules]
    /// Every child's entries for the month; `MonthSheet` narrows them down.
    @Query private var monthEntries: [DayEntry]
    /// Likewise every child's extra tasks for the month.
    @Query private var monthExtras: [ExtraTask]

    @State private var lastTap: HabitTap?
    @State private var saveFailed = false

    init(child: Child, month: CalendarMonth, navigation: DayNavigation) {
        self.child = child
        self.month = month
        self.navigation = navigation
        let interval = month.interval(in: navigation.calendar)
        let start = interval.start
        let end = interval.end
        _monthEntries = Query(filter: #Predicate<DayEntry> { $0.date >= start && $0.date < end })
        _monthExtras = Query(filter: #Predicate<ExtraTask> { $0.date >= start && $0.date < end })
    }

    var body: some View {
        let sheet = makeSheet()
        VStack(spacing: 16) {
            TileRow {
                StatTile(title: String(localized: "Month total"), value: Money.format(sheet.total))
                StatTile(title: String(localized: "Perfect days"), value: sheet.perfectDays.formatted())
            }
            if month < navigation.currentMonth {
                EarlierMonthBanner()
            }
            MonthGrid(sheet: sheet) { row, dayIndex in
                tap(row, dayIndex: dayIndex, in: sheet)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            if !sheet.extraTasks.isEmpty {
                ExtraTaskList(tasks: sheet.extraTasks)
            }
        }
        .habitTapFeedback(lastTap, saveFailed: $saveFailed)
    }

    private func makeSheet() -> MonthSheet {
        let rules = MonthRules.rules(for: month, from: savedRules)
        return MonthSheet(
            child: child, month: month, today: navigation.today, habits: habits,
            entries: monthEntries, extraTasks: monthExtras, rules: rules, calendar: navigation.calendar
        )
    }

    private func tap(_ row: MonthSheet.Row, dayIndex: Int, in sheet: MonthSheet) {
        guard !sheet.isLocked(dayIndex: dayIndex) else { return }
        let status = row.statuses[dayIndex].next
        let day = sheet.days[dayIndex]
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
