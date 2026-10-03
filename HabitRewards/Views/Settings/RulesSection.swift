import Foundation
import SwiftData
import SwiftUI

/// Reward and penalty for this month and next. Earlier months keep their own snapshot.
struct RulesSection: View {
    let navigation: DayNavigation
    let saveFailed: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var savedRules: [MonthRules]
    @Query(filter: #Predicate<Habit> { $0.isActive }) private var activeHabits: [Habit]
    @Query(filter: #Predicate<Child> { !$0.isArchived }, sort: \Child.sortOrder) private var children: [Child]

    var body: some View {
        let thisMonth = navigation.currentMonth
        let nextMonth = thisMonth.next
        Section {
            steppers(for: thisMonth, identifier: "thisMonth")
        } header: {
            Text("This month · \(name(of: thisMonth))")
                .foregroundStyle(.subtle)
        } footer: {
            Text("\(bestDay(in: thisMonth)) Changes apply to all of \(name(of: thisMonth)). Earlier months keep their own amounts.")
                .foregroundStyle(.subtle)
        }
        Section {
            steppers(for: nextMonth, identifier: "nextMonth")
        } header: {
            Text("Next month · \(name(of: nextMonth))")
                .foregroundStyle(.subtle)
        } footer: {
            Text("Starts on \(nextMonth.firstDay(in: navigation.calendar).formatted(.dateTime.day().month(.wide))). Until you change it, it carries on with this month's amounts.")
                .foregroundStyle(.subtle)
        }
    }

    @ViewBuilder
    private func steppers(for month: CalendarMonth, identifier: String) -> some View {
        let rules = MonthRules.rules(for: month, from: savedRules)
        MoneyStepper(title: "Reward per habit done", pence: rules.rewardPence) {
            save(ScoringRules(rewardPence: $0, penaltyPence: rules.penaltyPence), for: month)
        }
        .accessibilityIdentifier("\(identifier)Reward")
        MoneyStepper(title: "Penalty per habit missed", pence: rules.penaltyPence) {
            save(ScoringRules(rewardPence: rules.rewardPence, penaltyPence: $0), for: month)
        }
        .accessibilityIdentifier("\(identifier)Penalty")
    }

    private func save(_ rules: ScoringRules, for month: CalendarMonth) {
        do {
            try MonthRules.set(rules, for: month, in: context)
        } catch {
            context.rollback()
            saveFailed()
        }
    }

    private func name(of month: CalendarMonth) -> String {
        month.firstDay(in: navigation.calendar).formatted(.dateTime.month(.wide))
    }

    private func bestDay(in month: CalendarMonth) -> String {
        BestDay.summary(rules: MonthRules.rules(for: month, from: savedRules), activeHabits: activeHabits, children: children)
    }
}

/// The most a child can earn in a day: every one of their habits done.
enum BestDay {
    /// "Best day: £3.00." or, when the children have different habits,
    /// "Best day: Maya £3.00, Leo £2.00."
    static func summary(rules: ScoringRules, activeHabits: [Habit], children: [Child]) -> String {
        let engine = ScoringEngine(rules: rules)
        let amounts = children.map { child in
            (name: child.name, pence: engine.dayScore(done: activeHabits.filter { $0.isFor(child) }.count, missed: 0))
        }
        guard let first = amounts.first, amounts.contains(where: { $0.pence != first.pence }) else {
            let pence = amounts.first?.pence ?? engine.dayScore(done: activeHabits.count, missed: 0)
            return String(localized: "Best day: \(Money.format(pence)).")
        }
        let list = amounts.map { "\($0.name) \(Money.format($0.pence))" }.formatted(.list(type: .and, width: .narrow))
        return String(localized: "Best day: \(list).")
    }
}

/// A reward or penalty in the phone's currency. Type the amount, or step it by 5 of the smallest
/// unit (5p, 5¢, ¥5).
private struct MoneyStepper: View {
    let title: LocalizedStringKey
    let pence: Int
    let onChange: (Int) -> Void

    /// What's in the field. Read only when typing ends, so it isn't reformatted under the parent's
    /// fingers.
    @State private var text = ""
    @FocusState private var typing: Bool

    /// Only a guard against typing slips: big enough for any currency's pocket money.
    private static let maximum = 10_000_000

    var body: some View {
        Stepper(value: Binding(get: { pence }, set: onChange), in: 0...Self.maximum, step: 5) {
            HStack {
                Text(title)
                Spacer()
                // A short placeholder: the field sizes itself to it, and the title would squeeze the label.
                TextField(Money.format(0), text: $text)
                    .accessibilityLabel(Text(title))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .foregroundStyle(.subtle)
                    .focused($typing)
                    .fixedSize()
            }
        }
        .onAppear { text = Money.format(pence) }
        .onChange(of: pence) {
            if !typing { text = Money.format(pence) }
        }
        .onChange(of: typing) { _, isTyping in
            if isTyping {
                // A bare number is easier to edit: "0.50" rather than "£0.50".
                text = Money.editable(pence)
            } else {
                let typed = Money.pence(fromTyped: text).map { min(max($0, 0), Self.maximum) }
                if let typed, typed != pence { onChange(typed) }
                text = Money.format(typed ?? pence)
            }
        }
        .toolbar {
            // The number pad has no return key. Only the field being typed in adds the button,
            // so the four amounts don't add four.
            if typing {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { typing = false }
                }
            }
        }
        // VoiceOver: "Reward per habit done, £0.50, adjustable".
        .accessibilityLabel(Text(title))
        .accessibilityValue(Money.format(pence))
    }
}
