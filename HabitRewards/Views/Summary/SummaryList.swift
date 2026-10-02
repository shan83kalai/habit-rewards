import Foundation
import SwiftData
import SwiftUI

/// A summary card per child for one month.
struct SummaryList: View {
    let children: [Child]
    let month: CalendarMonth
    let navigation: DayNavigation

    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var savedRules: [MonthRules]
    @Query private var monthEntries: [DayEntry]
    @Query private var payouts: [Payout]

    @State private var saveFailed = false

    init(children: [Child], month: CalendarMonth, navigation: DayNavigation) {
        self.children = children
        self.month = month
        self.navigation = navigation
        let interval = month.interval(in: navigation.calendar)
        let start = interval.start
        let end = interval.end
        let year = month.year
        let monthNumber = month.month
        _monthEntries = Query(filter: #Predicate<DayEntry> { $0.date >= start && $0.date < end })
        _payouts = Query(filter: #Predicate<Payout> { $0.year == year && $0.month == monthNumber })
    }

    var body: some View {
        let rules = MonthRules.rules(for: month, from: savedRules)
        let sheets = children.map { child in
            (child: child, sheet: MonthSheet(
                child: child, month: month, today: navigation.today, habits: habits,
                entries: monthEntries, rules: rules, calendar: navigation.calendar
            ))
        }
        VStack(spacing: 16) {
            ForEach(sheets, id: \.child.id) { item in
                ChildSummaryCard(
                    child: item.child,
                    month: month,
                    sheet: item.sheet,
                    payments: Payout.payments(to: item.child, for: month, from: payouts),
                    markPaid: { pay($0, to: item.child) },
                    undo: undo
                )
                .tint(Color(hex: item.child.colourHex))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ShareMonthMenu(report: MonthReport(title: monthTitle, sheets: sheets.map { (name: $0.child.name, sheet: $0.sheet) }))
            }
        }
        .alert("Couldn't save that payment", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }

    private var monthTitle: String {
        month.firstDay(in: navigation.calendar).formatted(.dateTime.month(.wide).year())
    }

    private func pay(_ pence: Int, to child: Child) {
        Payout.record(pence, to: child, for: month, in: context)
        save()
    }

    private func undo(_ payout: Payout) {
        let name = payout.cloudRecordName
        context.delete(payout)
        save(deleted: [name])
    }

    private func save(deleted: [String] = []) {
        do {
            try context.save()
            LocalChanges.post(deleted: deleted)
        } catch {
            context.rollback()
            saveFailed = true
        }
    }
}
