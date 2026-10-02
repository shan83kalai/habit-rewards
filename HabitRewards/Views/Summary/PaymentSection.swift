import Foundation
import SwiftUI

/// What's been paid for the month, and the "Mark as paid" button for whatever is still owed.
struct PaymentSection: View {
    let childName: String
    let month: CalendarMonth
    let status: PayoutStatus
    let lastPayment: Payout?
    let markPaid: (Int) -> Void
    let undo: (Payout) -> Void

    @Environment(ParentLock.self) private var parentLock
    @State private var confirmingPayment = false
    @State private var confirmingUndo = false

    private var monthName: String {
        month.firstDay(in: .current).formatted(.dateTime.month(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if status.paidPence > 0 {
                Label(paidSummary, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }

            if status.overpaidPence > 0 {
                Label(
                    "\(Money.format(status.overpaidPence)) more than is now earned: ticks were changed after paying.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            if status.outstandingPence > 0 {
                Button {
                    askParent { confirmingPayment = true }
                } label: {
                    Text(status.paidPence > 0
                         ? "Pay the extra \(Money.format(status.outstandingPence))"
                         : "Mark \(Money.format(status.outstandingPence)) as paid")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if status.paidPence == 0 {
                Text("Nothing earned yet")
                    .foregroundStyle(.subtle)
            }

            if lastPayment != nil {
                Button("Undo last payment", role: .destructive) { askParent { confirmingUndo = true } }
                    .font(.footnote)
            }
        }
        .confirmationDialog(
            "Pay \(childName) \(Money.format(status.outstandingPence)) for \(monthName)?",
            isPresented: $confirmingPayment,
            titleVisibility: .visible
        ) {
            Button("Mark as paid") { markPaid(status.outstandingPence) }
        }
        .confirmationDialog(
            "Undo the \(Money.format(lastPayment?.amountPence ?? 0)) payment?",
            isPresented: $confirmingUndo,
            titleVisibility: .visible
        ) {
            Button("Undo payment", role: .destructive) {
                if let lastPayment { undo(lastPayment) }
            }
        }
    }

    /// Payments are for parents: unlock first, then confirm.
    private func askParent(then confirm: @escaping () -> Void) {
        Task {
            if await parentLock.authorize(reason: ParentLock.Reason.payment) { confirm() }
        }
    }

    /// "Paid £12.50 · 3 Nov"
    private var paidSummary: String {
        let amount = Money.format(status.paidPence)
        guard let date = lastPayment?.paidOn else { return String(localized: "Paid \(amount)") }
        return String(localized: "Paid \(amount) · \(date.formatted(.dateTime.day().month(.abbreviated)))")
    }
}
