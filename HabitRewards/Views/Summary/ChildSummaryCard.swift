import Foundation
import SwiftData
import SwiftUI

/// One child's month: total, perfect days, best streak, best and most-missed habit, and payment.
struct ChildSummaryCard: View {
    let child: Child
    let month: CalendarMonth
    let sheet: MonthSheet
    let payments: [Payout]
    let markPaid: (Int) -> Void
    let undo: (Payout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(child.name)
                    .font(.title2.bold())
                Spacer()
                Text(Money.format(sheet.total))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)

            TileRow {
                StatTile(title: String(localized: "Perfect days"), value: sheet.perfectDays.formatted())
                StatTile(title: String(localized: "Best streak"), value: dayCount(sheet.bestStreak))
            }

            VStack(alignment: .leading, spacing: 10) {
                HabitHighlight(
                    title: "Best habit", habit: sheet.mostDoneHabit,
                    detail: sheet.mostDoneHabit.map { inflected("Done ^[\(sheet.count(.done, for: $0)) time](inflect: true)") },
                    empty: "Nothing ticked yet"
                )
                HabitHighlight(
                    title: "Most missed", habit: sheet.mostMissedHabit,
                    detail: sheet.mostMissedHabit.map { inflected("Missed ^[\(sheet.count(.missed, for: $0)) time](inflect: true)") },
                    empty: "Nothing missed"
                )
            }

            Divider()

            PaymentSection(
                childName: child.name,
                month: month,
                status: PayoutStatus(earnedPence: sheet.total, payments: payments.map(\.amountPence)),
                lastPayment: payments.last,
                markPaid: markPaid,
                undo: undo
            )
        }
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 20))
        .animation(.snappy, value: sheet.total)
    }

    /// "1 day", "3 days".
    private func dayCount(_ count: Int) -> String {
        inflected("^[\(count) day](inflect: true)")
    }

    /// Resolves `^[…](inflect: true)` markup, so counts read "1 time" / "2 times".
    private func inflected(_ text: String.LocalizationValue) -> String {
        String(AttributedString(localized: text).characters)
    }
}

private struct HabitHighlight: View {
    let title: LocalizedStringKey
    let habit: Habit?
    let detail: String?
    let empty: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: habit?.sfSymbol ?? "minus")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.subtle)
                if let habit {
                    Text(habit.title).font(.body.weight(.medium))
                    if let detail { Text(detail).font(.caption).foregroundStyle(.subtle) }
                } else {
                    Text(empty).foregroundStyle(.subtle)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
