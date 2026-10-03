import Foundation
import SwiftData

/// Everything in the app as one JSON file, for backing up through the Files app and restoring.
nonisolated struct Backup: Codable, Equatable, Sendable {
    /// 2 added `HabitRecord.childIDs`; 3 added `extraTasks`.
    static let currentVersion = 3

    struct ChildRecord: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var colourHex: String
        var sortOrder: Int
        var isArchived: Bool
    }

    struct HabitRecord: Codable, Equatable, Sendable {
        var id: UUID
        var title: String
        var sfSymbol: String
        var sortOrder: Int
        var isActive: Bool
        /// The children it's for; missing for habits that are for everyone, and in version 1 files.
        var childIDs: [UUID]?
    }

    struct RulesRecord: Codable, Equatable, Sendable {
        var year: Int
        var month: Int
        var rewardPence: Int
        var penaltyPence: Int
    }

    struct EntryRecord: Codable, Equatable, Sendable {
        var childID: UUID
        var habitID: UUID
        /// "yyyy-MM-dd", so a day stays the same day whatever time zone it's restored in.
        var day: String
        var status: HabitStatus
    }

    struct PayoutRecord: Codable, Equatable, Sendable {
        var childID: UUID
        var year: Int
        var month: Int
        var amountPence: Int
        var paidOn: Date?
    }

    struct ExtraTaskRecord: Codable, Equatable, Sendable {
        var id: UUID
        var childID: UUID
        var title: String
        var rewardPence: Int
        /// "yyyy-MM-dd", like `EntryRecord.day`.
        var day: String
        var isDone: Bool
        var createdAt: Date
    }

    enum RestoreError: Error, Equatable {
        /// Not JSON, or not a Habit Rewards backup.
        case unreadable
        /// Made by a newer version of the app than this one.
        case newerVersion
        /// A tick, payment or extra task points at a child or habit that isn't in the file.
        case brokenReference
        /// A day that doesn't exist, e.g. "2026-13-45".
        case badDay
    }

    var version: Int
    var exportedAt: Date
    var children: [ChildRecord]
    var habits: [HabitRecord]
    var monthRules: [RulesRecord]
    var entries: [EntryRecord]
    var payouts: [PayoutRecord]
    /// Missing in files from before version 3.
    var extraTasks: [ExtraTaskRecord]?

    var tickCount: Int {
        entries.filter { $0.status != .unset }.count
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Backup {
        struct VersionOnly: Decodable { let version: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let version = try? decoder.decode(VersionOnly.self, from: data).version else { throw RestoreError.unreadable }
        guard version <= currentVersion else { throw RestoreError.newerVersion }
        guard let backup = try? decoder.decode(Backup.self, from: data) else { throw RestoreError.unreadable }
        return backup
    }
}

extension Backup {
    /// A snapshot of everything in the store.
    static func make(from context: ModelContext, calendar: Calendar = .current, now: Date = .now) throws -> Backup {
        let entries = try context.fetch(FetchDescriptor<DayEntry>()).compactMap { entry -> EntryRecord? in
            guard let childID = entry.child?.id, let habitID = entry.habit?.id else { return nil }
            return EntryRecord(childID: childID, habitID: habitID, day: DayEntry.dayString(for: entry.date, calendar: calendar), status: entry.status)
        }
        let payouts = try context.fetch(FetchDescriptor<Payout>(sortBy: [SortDescriptor(\.paidOn)])).compactMap { payout -> PayoutRecord? in
            guard let childID = payout.child?.id else { return nil }
            return PayoutRecord(childID: childID, year: payout.year, month: payout.month, amountPence: payout.amountPence, paidOn: payout.paidOn)
        }
        let extraTasks = try context.fetch(FetchDescriptor<ExtraTask>(sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt)])).compactMap { task -> ExtraTaskRecord? in
            guard let childID = task.child?.id ?? task.childID else { return nil }
            return ExtraTaskRecord(id: task.id, childID: childID, title: task.title, rewardPence: task.rewardPence, day: task.day, isDone: task.isDone, createdAt: task.createdAt)
        }
        return Backup(
            version: currentVersion,
            exportedAt: now,
            children: try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)])).map {
                ChildRecord(id: $0.id, name: $0.name, colourHex: $0.colourHex, sortOrder: $0.sortOrder, isArchived: $0.isArchived)
            },
            habits: try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)])).map {
                HabitRecord(id: $0.id, title: $0.title, sfSymbol: $0.sfSymbol, sortOrder: $0.sortOrder, isActive: $0.isActive, childIDs: $0.childIDs.isEmpty ? nil : $0.childIDs)
            },
            monthRules: try context.fetch(FetchDescriptor<MonthRules>()).map {
                RulesRecord(year: $0.year, month: $0.month, rewardPence: $0.rewardPence, penaltyPence: $0.penaltyPence)
            }.sorted { ($0.year, $0.month) < ($1.year, $1.month) },
            entries: entries.sorted { ($0.day, $0.childID.uuidString, $0.habitID.uuidString) < ($1.day, $1.childID.uuidString, $1.habitID.uuidString) },
            payouts: payouts,
            extraTasks: extraTasks
        )
    }

    /// Replaces everything in the store with this backup. The whole file is checked first, and
    /// it's saved in one go, so a bad file or a failed save leaves the current data untouched.
    func restore(into context: ModelContext, calendar: Calendar = .current) throws {
        let childIDs = Set(children.map(\.id))
        let habitIDs = Set(habits.map(\.id))
        guard entries.allSatisfy({ childIDs.contains($0.childID) && habitIDs.contains($0.habitID) }),
              payouts.allSatisfy({ childIDs.contains($0.childID) })
        else { throw RestoreError.brokenReference }
        let days = try entries.map { entry in
            guard let date = DayEntry.date(fromDayString: entry.day, calendar: calendar) else { throw RestoreError.badDay }
            return date
        }
        let tasks = extraTasks ?? []
        guard tasks.allSatisfy({ childIDs.contains($0.childID) }) else { throw RestoreError.brokenReference }
        let taskDays = try tasks.map { task in
            guard let date = DayEntry.date(fromDayString: task.day, calendar: calendar) else { throw RestoreError.badDay }
            return date
        }

        do {
            try deleteEverything(in: context)

            var childrenByID: [UUID: Child] = [:]
            for record in children {
                let child = Child(name: record.name, colourHex: record.colourHex, sortOrder: record.sortOrder)
                child.id = record.id
                child.isArchived = record.isArchived
                context.insert(child)
                childrenByID[record.id] = child
            }
            var habitsByID: [UUID: Habit] = [:]
            for record in habits {
                let habit = Habit(title: record.title, sfSymbol: record.sfSymbol, sortOrder: record.sortOrder)
                habit.id = record.id
                habit.isActive = record.isActive
                habit.childIDs = record.childIDs ?? []
                context.insert(habit)
                habitsByID[record.id] = habit
            }
            for record in monthRules {
                context.insert(MonthRules(year: record.year, month: record.month, rules: ScoringRules(rewardPence: record.rewardPence, penaltyPence: record.penaltyPence)))
            }
            for (record, day) in zip(entries, days) {
                guard let child = childrenByID[record.childID], let habit = habitsByID[record.habitID] else { continue }
                try DayEntry.upsert(child: child, habit: habit, date: day, status: record.status, in: context, calendar: calendar)
            }
            for record in payouts {
                let payout = Payout(year: record.year, month: record.month, amountPence: record.amountPence, paidOn: record.paidOn)
                context.insert(payout)
                payout.child = childrenByID[record.childID]
                payout.childID = record.childID
            }
            for (record, date) in zip(tasks, taskDays) {
                let task = ExtraTask(title: record.title, rewardPence: record.rewardPence)
                task.id = record.id
                task.day = record.day
                task.date = date
                task.isDone = record.isDone
                task.createdAt = record.createdAt
                context.insert(task)
                task.child = childrenByID[record.childID]
                task.childID = record.childID
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func deleteEverything(in context: ModelContext) throws {
        for entry in try context.fetch(FetchDescriptor<DayEntry>()) { context.delete(entry) }
        for payout in try context.fetch(FetchDescriptor<Payout>()) { context.delete(payout) }
        for task in try context.fetch(FetchDescriptor<ExtraTask>()) { context.delete(task) }
        for rules in try context.fetch(FetchDescriptor<MonthRules>()) { context.delete(rules) }
        for child in try context.fetch(FetchDescriptor<Child>()) { context.delete(child) }
        for habit in try context.fetch(FetchDescriptor<Habit>()) { context.delete(habit) }
    }
}
