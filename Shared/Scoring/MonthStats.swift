/// How often one habit was done and missed in a month.
nonisolated struct HabitTally<ID: Hashable>: Hashable {
    let id: ID
    let done: Int
    let missed: Int

    init(id: ID, statuses: some Sequence<HabitStatus>) {
        var done = 0
        var missed = 0
        for status in statuses {
            switch status {
            case .done: done += 1
            case .missed: missed += 1
            case .unset: break
            }
        }
        self.id = id
        self.done = done
        self.missed = missed
    }
}

/// Summary statistics for a month. Pure, like `ScoringEngine`.
nonisolated enum MonthStats {
    /// Every habit that counts that day is done. A day with no habits isn't perfect.
    static func isPerfectDay(_ statuses: some Collection<HabitStatus>) -> Bool {
        !statuses.isEmpty && statuses.allSatisfy { $0 == .done }
    }

    /// The longest run of consecutive perfect days.
    static func longestStreak(_ perfectDays: some Sequence<Bool>) -> Int {
        var longest = 0
        var current = 0
        for isPerfect in perfectDays {
            current = isPerfect ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }

    /// The habit done most often, or `nil` if nothing was done. Ties go to the earlier habit.
    static func mostDone<ID>(_ tallies: [HabitTally<ID>]) -> ID? {
        highest(tallies, by: \.done)
    }

    /// The habit missed most often, or `nil` if nothing was missed. Ties go to the earlier habit.
    static func mostMissed<ID>(_ tallies: [HabitTally<ID>]) -> ID? {
        highest(tallies, by: \.missed)
    }

    private static func highest<ID>(_ tallies: [HabitTally<ID>], by count: (HabitTally<ID>) -> Int) -> ID? {
        // Strictly greater, so the first of any tie wins; starting from 0 means all-zero gives nil.
        var best: HabitTally<ID>?
        for tally in tallies where count(tally) > (best.map(count) ?? 0) {
            best = tally
        }
        return best?.id
    }
}
