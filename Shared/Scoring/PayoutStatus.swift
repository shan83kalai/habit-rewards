/// What a child earned in a month against what they've been paid for it, in pence.
/// Several payments are allowed so late ticks can be topped up rather than overwriting a payment.
nonisolated struct PayoutStatus: Equatable, Sendable {
    let earnedPence: Int
    let paidPence: Int

    init(earnedPence: Int, payments: some Sequence<Int>) {
        self.earnedPence = earnedPence
        self.paidPence = payments.reduce(0, +)
    }

    var outstandingPence: Int { max(0, earnedPence - paidPence) }

    /// More was paid than is now earned, e.g. ticks were removed after paying.
    var overpaidPence: Int { max(0, paidPence - earnedPence) }

    var isSettled: Bool { outstandingPence == 0 }
}
