/// Reward and penalty for one month, in pence.
nonisolated struct ScoringRules: Hashable, Sendable {
    var rewardPence: Int
    var penaltyPence: Int

    /// 50p per habit done, 75p per habit missed.
    static let standard = ScoringRules(rewardPence: 50, penaltyPence: 75)
}

/// Pure scoring maths. All money is integer pence (the currency's smallest unit); formatting happens in the UI.
nonisolated struct ScoringEngine: Sendable {
    var rules: ScoringRules

    init(rules: ScoringRules = .standard) {
        self.rules = rules
    }

    /// `max(0, done × reward − missed × penalty)`.
    func dayScore(done: Int, missed: Int) -> Int {
        max(0, done * rules.rewardPence - missed * rules.penaltyPence)
    }

    /// Scores one day from its habit statuses. `unset` counts as nothing.
    func dayScore(_ statuses: some Sequence<HabitStatus>) -> Int {
        var done = 0
        var missed = 0
        for status in statuses {
            switch status {
            case .done: done += 1
            case .missed: missed += 1
            case .unset: break
            }
        }
        return dayScore(done: done, missed: missed)
    }

    /// Sums the month's day scores. Each day is floored at 0 before it is added.
    func monthTotal<Days: Sequence>(_ days: Days) -> Int where Days.Element: Sequence<HabitStatus> {
        days.reduce(0) { $0 + dayScore($1) }
    }

    func monthTotal(dayScores: some Sequence<Int>) -> Int {
        dayScores.reduce(0, +)
    }

    /// Groups stored entries by day, floors each day at 0, then sums. `Day` is any per-day key.
    func monthTotal<Day: Hashable>(entries: some Sequence<(day: Day, status: HabitStatus)>) -> Int {
        var statusesByDay: [Day: [HabitStatus]] = [:]
        for entry in entries {
            statusesByDay[entry.day, default: []].append(entry.status)
        }
        return monthTotal(statusesByDay.values)
    }
}
