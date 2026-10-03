import CloudKit
import Foundation
import SwiftData

/// The five record types in the family zone, told apart by the prefix of their record name.
enum SyncRecordKind: String, CaseIterable {
    case child = "child-"
    case habit = "habit-"
    case rules = "rules-"
    case entry = "entry_"
    case payout = "payout-"

    init?(recordName: String) {
        guard let kind = Self.allCases.first(where: { recordName.hasPrefix($0.rawValue) }) else { return nil }
        self = kind
    }

    var recordType: String {
        switch self {
        case .child: "Child"
        case .habit: "Habit"
        case .rules: "MonthRules"
        case .entry: "DayEntry"
        case .payout: "Payout"
        }
    }
}

/// A model that can be written into a CloudKit record. Relationships travel as plain IDs, so
/// records can arrive in any order.
protocol CloudRecordConvertible: Syncable {
    static var kind: SyncRecordKind { get }
    func encode(into record: CKRecord)
    /// Takes the values from an arriving record. Identity fields (IDs, keys) are set by the caller.
    func decode(from record: CKRecord)
}

extension CloudRecordConvertible {
    /// This model as a record, reusing CloudKit's system fields when it has been synced before.
    func cloudRecord(in zone: CKRecordZone.ID) -> CKRecord {
        let record = cloudSystemFields.flatMap(CKRecord.init(systemFields:))
            ?? CKRecord(recordType: Self.kind.recordType, recordID: CKRecord.ID(recordName: cloudRecordName, zoneID: zone))
        encode(into: record)
        record[SyncField.modifiedAt] = modifiedAt
        return record
    }
}

nonisolated enum SyncField {
    static let modifiedAt = "modifiedAt"
}

extension Child: CloudRecordConvertible {
    static let kind = SyncRecordKind.child

    func encode(into record: CKRecord) {
        record["name"] = name
        record["colourHex"] = colourHex
        record["sortOrder"] = sortOrder
        record["isArchived"] = isArchived
    }

    func decode(from record: CKRecord) {
        name = record["name"] as? String ?? name
        colourHex = record["colourHex"] as? String ?? colourHex
        sortOrder = record["sortOrder"] as? Int ?? sortOrder
        isArchived = record["isArchived"] as? Bool ?? isArchived
    }
}

extension Habit: CloudRecordConvertible {
    static let kind = SyncRecordKind.habit

    func encode(into record: CKRecord) {
        record["title"] = title
        record["sfSymbol"] = sfSymbol
        record["sortOrder"] = sortOrder
        record["isActive"] = isActive
        // No value, rather than an empty list, means every child.
        record["childIDs"] = childIDs.isEmpty ? nil : childIDs.map(\.uuidString)
    }

    func decode(from record: CKRecord) {
        title = record["title"] as? String ?? title
        sfSymbol = record["sfSymbol"] as? String ?? sfSymbol
        sortOrder = record["sortOrder"] as? Int ?? sortOrder
        isActive = record["isActive"] as? Bool ?? isActive
        // CloudKit returns an empty list as no value, and older versions never set it: both mean
        // every child, so a missing value can't keep this phone's old choice.
        childIDs = (record["childIDs"] as? [String] ?? []).compactMap(UUID.init(uuidString:))
    }
}

extension MonthRules: CloudRecordConvertible {
    static let kind = SyncRecordKind.rules

    func encode(into record: CKRecord) {
        record["year"] = year
        record["month"] = month
        record["rewardPence"] = rewardPence
        record["penaltyPence"] = penaltyPence
    }

    func decode(from record: CKRecord) {
        rewardPence = record["rewardPence"] as? Int ?? rewardPence
        penaltyPence = record["penaltyPence"] as? Int ?? penaltyPence
    }
}

extension DayEntry: CloudRecordConvertible {
    static let kind = SyncRecordKind.entry

    /// The key travels whole: it names the child, day and habit, so the receiving phone can
    /// rebuild the entry (and link it) without the date's time zone getting involved.
    func encode(into record: CKRecord) {
        record["key"] = key
        record["status"] = status.rawValue
    }

    func decode(from record: CKRecord) {
        statusRaw = (record["status"] as? String).flatMap(HabitStatus.init(rawValue:))?.rawValue ?? statusRaw
    }
}

extension Payout: CloudRecordConvertible {
    static let kind = SyncRecordKind.payout

    func encode(into record: CKRecord) {
        record["childID"] = childID?.uuidString ?? child?.id.uuidString
        record["year"] = year
        record["month"] = month
        record["amountPence"] = amountPence
        record["paidOn"] = paidOn
    }

    func decode(from record: CKRecord) {
        childID = (record["childID"] as? String).flatMap(UUID.init(uuidString:)) ?? childID
        year = record["year"] as? Int ?? year
        month = record["month"] as? Int ?? month
        amountPence = record["amountPence"] as? Int ?? amountPence
        paidOn = record["paidOn"] as? Date
    }
}

extension CKRecord {
    /// A record rebuilt from saved system fields (ID, type and change tag, no values).
    nonisolated convenience init?(systemFields data: Data) {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        self.init(coder: coder)
        coder.finishDecoding()
    }

    nonisolated var systemFieldsData: Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    nonisolated var modifiedAtField: Date {
        self[SyncField.modifiedAt] as? Date ?? .distantPast
    }
}
