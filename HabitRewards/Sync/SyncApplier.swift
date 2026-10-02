import CloudKit
import Foundation
import SwiftData

/// Applies records that arrive from iCloud to this phone's store, and keeps track of what still
/// has to upload. No CloudKit calls here, so it's all unit-tested.
enum SyncApplier {
    // MARK: - Arriving changes

    /// Merges `records` and removes `deletions` (record names). For each record the newer change
    /// wins: an arrival replaces the local copy unless this phone has a newer change of its own
    /// still waiting to upload.
    static func apply(_ records: [CKRecord], deletions: [String], to context: ModelContext, calendar: Calendar = .current) throws {
        // Children and habits first, so ticks and payments in the same batch can be linked straight away.
        let ordered = records.sorted { rank($0) < rank($1) }
        for record in ordered {
            guard let kind = SyncRecordKind(recordName: record.recordID.recordName) else { continue }
            let name = record.recordID.recordName
            switch kind {
            case .child:
                guard let id = uuid(in: name, after: kind) else { continue }
                merge(record, into: try find(Child.self, id: id, in: context) ?? insertChild(id: id, in: context))
            case .habit:
                guard let id = uuid(in: name, after: kind) else { continue }
                merge(record, into: try find(Habit.self, id: id, in: context) ?? insertHabit(id: id, in: context))
            case .rules:
                guard let month = month(in: name) else { continue }
                merge(record, into: try MonthRules.saved(for: month, in: context) ?? insert(MonthRules(year: month.year, month: month.month), in: context))
            case .entry:
                guard let key = record["key"] as? String, let parts = DayEntry.parts(ofKey: key) else { continue }
                let entry = try findEntry(key: key, in: context)
                    ?? insert(DayEntry.fromSync(key: key, date: DayEntry.date(fromDayString: parts.day, calendar: calendar) ?? .distantPast, status: .unset), in: context)
                merge(record, into: entry)
            case .payout:
                guard let id = uuid(in: name, after: kind) else { continue }
                let payout = try find(Payout.self, id: id, in: context) ?? insertPayout(id: id, in: context)
                merge(record, into: payout)
            }
        }
        for name in deletions {
            if let model = try model(named: name, in: context) as? any PersistentModel {
                context.delete(model)
            }
        }
        try linkOrphans(in: context)
        try context.save()
    }

    /// Takes the arrival unless this phone has a newer change still to upload. Either way the
    /// model keeps the server's system fields, so its next upload replaces the latest version.
    private static func merge<Model: CloudRecordConvertible>(_ record: CKRecord, into model: Model) {
        model.cloudSystemFields = record.systemFieldsData
        let arrived = record.modifiedAtField
        if model.hasUnsyncedChanges && model.modifiedAt > arrived { return }
        model.decode(from: record)
        model.modifiedAt = arrived
        model.syncedAt = arrived
    }

    /// Links ticks and payments that arrived before their child or habit.
    private static func linkOrphans(in context: ModelContext) throws {
        let children = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Child>()).map { ($0.id, $0) })
        let habits = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Habit>()).map { ($0.id, $0) })
        for entry in try context.fetch(FetchDescriptor<DayEntry>()) where entry.child == nil || entry.habit == nil {
            guard let parts = DayEntry.parts(ofKey: entry.key) else { continue }
            if entry.child == nil { entry.child = children[parts.childID] }
            if entry.habit == nil { entry.habit = habits[parts.habitID] }
        }
        for payout in try context.fetch(FetchDescriptor<Payout>()) where payout.child == nil {
            payout.child = payout.childID.flatMap { children[$0] }
        }
    }

    // MARK: - Uploading

    /// Records changed on this phone since they last went to (or came from) iCloud.
    static func pendingRecordNames(in context: ModelContext) throws -> [String] {
        var names: [String] = []
        names += try context.fetch(FetchDescriptor<Child>(predicate: #Predicate { $0.modifiedAt > $0.syncedAt })).map(\.cloudRecordName)
        names += try context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { $0.modifiedAt > $0.syncedAt })).map(\.cloudRecordName)
        names += try context.fetch(FetchDescriptor<MonthRules>(predicate: #Predicate { $0.modifiedAt > $0.syncedAt })).map(\.cloudRecordName)
        names += try context.fetch(FetchDescriptor<DayEntry>(predicate: #Predicate { $0.modifiedAt > $0.syncedAt })).map(\.cloudRecordName)
        names += try context.fetch(FetchDescriptor<Payout>(predicate: #Predicate { $0.modifiedAt > $0.syncedAt })).map(\.cloudRecordName)
        return names
    }

    /// Every record, for the owner's first upload when sharing starts.
    static func allRecordNames(in context: ModelContext) throws -> [String] {
        try everything(in: context).map(\.cloudRecordName)
    }

    /// After an upload: each saved record is now in step, unless it changed again meanwhile.
    static func markSent(_ records: [CKRecord], in context: ModelContext) throws {
        for record in records {
            guard let model = try model(named: record.recordID.recordName, in: context) else { continue }
            model.cloudSystemFields = record.systemFieldsData
            model.syncedAt = max(model.syncedAt, record.modifiedAtField)
        }
        try context.save()
    }

    /// The record to upload for a pending change, or `nil` if the model has since been deleted.
    static func record(named name: String, zone: CKRecordZone.ID, in context: ModelContext) throws -> CKRecord? {
        try model(named: name, in: context)?.cloudRecord(in: zone)
    }

    /// Forgets which iCloud records this phone's data matched, after sharing stops.
    static func forgetCloudState(in context: ModelContext) throws {
        for model in try everything(in: context) {
            model.cloudSystemFields = nil
            model.syncedAt = .distantPast
        }
        try context.save()
    }

    /// Clears this phone's own data before it joins a family and takes on the family's.
    static func deleteEverything(in context: ModelContext) throws {
        for entry in try context.fetch(FetchDescriptor<DayEntry>()) { context.delete(entry) }
        for payout in try context.fetch(FetchDescriptor<Payout>()) { context.delete(payout) }
        for rules in try context.fetch(FetchDescriptor<MonthRules>()) { context.delete(rules) }
        for child in try context.fetch(FetchDescriptor<Child>()) { context.delete(child) }
        for habit in try context.fetch(FetchDescriptor<Habit>()) { context.delete(habit) }
        try context.save()
    }

    // MARK: - Finding models by record name

    static func model(named name: String, in context: ModelContext) throws -> (any CloudRecordConvertible)? {
        guard let kind = SyncRecordKind(recordName: name) else { return nil }
        switch kind {
        case .child: return try uuid(in: name, after: kind).flatMap { try find(Child.self, id: $0, in: context) }
        case .habit: return try uuid(in: name, after: kind).flatMap { try find(Habit.self, id: $0, in: context) }
        case .payout: return try uuid(in: name, after: kind).flatMap { try find(Payout.self, id: $0, in: context) }
        case .rules: return try month(in: name).flatMap { try MonthRules.saved(for: $0, in: context) }
        case .entry: return try context.fetch(FetchDescriptor<DayEntry>()).first { $0.cloudRecordName == name }
        }
    }

    private static func everything(in context: ModelContext) throws -> [any CloudRecordConvertible] {
        var all: [any CloudRecordConvertible] = []
        all += try context.fetch(FetchDescriptor<Child>()) as [any CloudRecordConvertible]
        all += try context.fetch(FetchDescriptor<Habit>()) as [any CloudRecordConvertible]
        all += try context.fetch(FetchDescriptor<MonthRules>()) as [any CloudRecordConvertible]
        all += try context.fetch(FetchDescriptor<DayEntry>()) as [any CloudRecordConvertible]
        all += try context.fetch(FetchDescriptor<Payout>()) as [any CloudRecordConvertible]
        return all
    }

    private static func find(_ type: Child.Type, id: UUID, in context: ModelContext) throws -> Child? {
        try context.fetch(FetchDescriptor<Child>(predicate: #Predicate { $0.id == id })).first
    }

    private static func find(_ type: Habit.Type, id: UUID, in context: ModelContext) throws -> Habit? {
        try context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })).first
    }

    private static func find(_ type: Payout.Type, id: UUID, in context: ModelContext) throws -> Payout? {
        try context.fetch(FetchDescriptor<Payout>(predicate: #Predicate { $0.id == id })).first
    }

    private static func findEntry(key: String, in context: ModelContext) throws -> DayEntry? {
        var descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func insertChild(id: UUID, in context: ModelContext) -> Child {
        let child = insert(Child(name: "", colourHex: "#7B61FF", sortOrder: 0), in: context)
        child.id = id
        return child
    }

    private static func insertHabit(id: UUID, in context: ModelContext) -> Habit {
        let habit = insert(Habit(title: "", sfSymbol: "checkmark.circle", sortOrder: 0), in: context)
        habit.id = id
        return habit
    }

    private static func insertPayout(id: UUID, in context: ModelContext) -> Payout {
        let payout = insert(Payout(year: 0, month: 1, amountPence: 0), in: context)
        payout.id = id
        return payout
    }

    private static func insert<Model: PersistentModel>(_ model: Model, in context: ModelContext) -> Model {
        context.insert(model)
        return model
    }

    private static func uuid(in name: String, after kind: SyncRecordKind) -> UUID? {
        UUID(uuidString: String(name.dropFirst(kind.rawValue.count)))
    }

    /// `rules-2026-10` → October 2026
    private static func month(in name: String) -> CalendarMonth? {
        let parts = name.dropFirst(SyncRecordKind.rules.rawValue.count).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2, (1...12).contains(parts[1]) else { return nil }
        return CalendarMonth(year: parts[0], month: parts[1])
    }

    private static func rank(_ record: CKRecord) -> Int {
        switch SyncRecordKind(recordName: record.recordID.recordName) {
        case .child, .habit: 0
        case .rules: 1
        case .entry, .payout: 2
        case nil: 3
        }
    }
}
