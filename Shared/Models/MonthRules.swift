import Foundation
import SwiftData

/// The reward and penalty in force for one calendar month. Snapshotted per month so
/// changing the rules later never rewrites an earlier month's payout.
@Model
final class MonthRules: Syncable {
    var id: UUID = UUID()
    var year: Int = 0
    /// 1...12
    var month: Int = 0
    var rewardPence: Int = ScoringRules.standard.rewardPence
    var penaltyPence: Int = ScoringRules.standard.penaltyPence

    // Sync bookkeeping: see `Syncable`.
    var modifiedAt: Date = Date.distantPast
    var syncedAt: Date = Date.distantPast
    var cloudSystemFields: Data?

    init(year: Int, month: Int, rules: ScoringRules = .standard) {
        self.year = year
        self.month = month
        self.rewardPence = rules.rewardPence
        self.penaltyPence = rules.penaltyPence
    }

    var rules: ScoringRules {
        get { ScoringRules(rewardPence: rewardPence, penaltyPence: penaltyPence) }
        set {
            rewardPence = newValue.rewardPence
            penaltyPence = newValue.penaltyPence
        }
    }

    var calendarMonth: CalendarMonth {
        CalendarMonth(year: year, month: month)
    }

    /// One record per month, so two phones snapshotting the same month share a record.
    var cloudRecordName: String { Self.cloudRecordName(for: calendarMonth) }

    nonisolated static func cloudRecordName(for month: CalendarMonth) -> String {
        String(format: "rules-%04d-%02d", month.year, month.month)
    }

    /// The rules for `month`: its own if saved, otherwise the latest saved before it (rules carry
    /// forward until changed), otherwise the standard rules. Later months never affect earlier ones.
    static func rules(for month: CalendarMonth, from saved: [MonthRules]) -> ScoringRules {
        saved
            .filter { $0.calendarMonth <= month }
            .max { $0.calendarMonth < $1.calendarMonth }?
            .rules ?? .standard
    }

    /// Saves `rules` for `month`, updating its row if it has one.
    static func set(_ rules: ScoringRules, for month: CalendarMonth, in context: ModelContext) throws {
        if let existing = try saved(for: month, in: context) {
            existing.rules = rules
            existing.touch()
        } else {
            let new = MonthRules(year: month.year, month: month.month, rules: rules)
            context.insert(new)
            new.touch()
        }
        try context.save()
        LocalChanges.post()
    }

    /// Gives `month` its own copy of the rules in force when it starts, unless it already has
    /// some (e.g. set in advance as "next month"). Safe to call on every launch.
    static func ensureSnapshot(for month: CalendarMonth, in context: ModelContext) throws {
        guard try saved(for: month, in: context) == nil else { return }
        let inForce = rules(for: month, from: try context.fetch(FetchDescriptor<MonthRules>()))
        let snapshot = MonthRules(year: month.year, month: month.month, rules: inForce)
        context.insert(snapshot)
        snapshot.touch()
        try context.save()
        LocalChanges.post()
    }

    static func saved(for month: CalendarMonth, in context: ModelContext) throws -> MonthRules? {
        let year = month.year
        let number = month.month
        var descriptor = FetchDescriptor<MonthRules>(predicate: #Predicate { $0.year == year && $0.month == number })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
