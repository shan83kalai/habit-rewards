import CloudKit
import SwiftData
import XCTest
@testable import HabitRewards

/// Family sharing logic that doesn't need iCloud: turning models into CloudKit records and back,
/// merging what arrives, and knowing what still has to upload.
final class SyncTests: SwiftDataTestCase {
    private let zone = CKRecordZone.ID(zoneName: "Family", ownerName: CKCurrentUserDefaultName)
    private let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()
    private let earlier = Date(timeIntervalSince1970: 1_790_000_000)
    private let later = Date(timeIntervalSince1970: 1_790_100_000)

    private func day(_ day: Int) -> Date {
        london.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
    }

    /// A phone with the seed children and habits, all already in step with iCloud.
    private func makePhone() throws -> (ModelContext, [Child], [Habit]) {
        let context = try makeContext()
        try SeedData.seedIfNeeded(context)
        let children = try context.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        markSynced(children, habits)
        try context.save()
        return (context, children, habits)
    }

    private func markSynced(_ groups: [any Syncable]...) {
        for model in groups.joined() {
            model.modifiedAt = earlier
            model.syncedAt = earlier
        }
    }

    private func records(_ groups: [any CloudRecordConvertible]...) -> [CKRecord] {
        groups.joined().map { $0.cloudRecord(in: zone) }
    }

    // MARK: - Records

    func testRecordNamesAreStableAndDistinct() throws {
        let (context, children, habits) = try makePhone()
        let entry = try DayEntry.upsert(child: children[0], habit: habits[0], date: day(2), status: .done, in: context, calendar: london)
        let rules = MonthRules(year: 2026, month: 10)

        XCTAssertEqual(children[0].cloudRecordName, "child-\(children[0].id.uuidString)")
        XCTAssertEqual(rules.cloudRecordName, "rules-2026-10")
        XCTAssertEqual(entry.cloudRecordName, "entry_\(children[0].id.uuidString)_2026-10-02_\(habits[0].id.uuidString)")
        XCTAssertEqual(SyncRecordKind(recordName: entry.cloudRecordName), .entry)
        XCTAssertEqual(SyncRecordKind(recordName: rules.cloudRecordName), .rules)
    }

    func testEveryModelRoundTripsThroughACloudKitRecord() throws {
        let (phoneA, children, habits) = try makePhone()
        children[1].isArchived = true
        habits[2].isActive = false
        habits[3].childIDs = [children[1].id]
        let entry = try DayEntry.upsert(child: children[0], habit: habits[2], date: day(2), status: .missed, in: phoneA, calendar: london)
        let rules = MonthRules(year: 2026, month: 10, rules: ScoringRules(rewardPence: 60, penaltyPence: 80))
        phoneA.insert(rules)
        let payout = Payout.record(475, to: children[0], for: CalendarMonth(year: 2026, month: 9), paidOn: day(1), in: phoneA)
        try phoneA.save()

        let sent = records(children, habits, [rules, entry, payout])
        let phoneB = try makeContext()
        try SyncApplier.apply(sent, deletions: [], to: phoneB, calendar: london)

        let childrenB = try phoneB.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(childrenB.map(\.id), children.map(\.id))
        XCTAssertEqual(childrenB.map(\.name), ["Child 1", "Child 2"])
        XCTAssertTrue(childrenB[1].isArchived)
        let habitsB = try phoneB.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(habitsB.map(\.title), habits.map(\.title))
        XCTAssertFalse(habitsB[2].isActive)
        XCTAssertEqual(habitsB[3].childIDs, [children[1].id])
        XCTAssertEqual(habitsB[0].childIDs, [])
        XCTAssertEqual(MonthRules.rules(for: CalendarMonth(year: 2026, month: 10), from: try phoneB.fetch(FetchDescriptor<MonthRules>())), ScoringRules(rewardPence: 60, penaltyPence: 80))

        let entryB = try XCTUnwrap(phoneB.fetch(FetchDescriptor<DayEntry>()).first)
        XCTAssertEqual(entryB.key, entry.key)
        XCTAssertEqual(entryB.status, .missed)
        XCTAssertEqual(entryB.date, day(2).addingTimeInterval(-12 * 3_600)) // start of day
        XCTAssertTrue(entryB.child === childrenB[0])
        XCTAssertTrue(entryB.habit === habitsB[2])

        let payoutB = try XCTUnwrap(phoneB.fetch(FetchDescriptor<Payout>()).first)
        XCTAssertEqual(payoutB.amountPence, 475)
        XCTAssertEqual(payoutB.paidOn, day(1))
        XCTAssertTrue(payoutB.child === childrenB[0])
    }

    func testRecordsKeepCloudKitsSystemFields() throws {
        let (_, children, _) = try makePhone()
        let record = children[0].cloudRecord(in: zone)
        children[0].cloudSystemFields = record.systemFieldsData

        let again = children[0].cloudRecord(in: zone)
        XCTAssertEqual(again.recordID, record.recordID)
        XCTAssertEqual(again.recordType, "Child")
    }

    // MARK: - Merging what arrives

    func testArrivingRecordsAreNotSentBackOut() throws {
        let (phoneA, children, habits) = try makePhone()
        let sent = records(children, habits)
        let phoneB = try makeContext()
        try SyncApplier.apply(sent, deletions: [], to: phoneB, calendar: london)
        XCTAssertEqual(try SyncApplier.pendingRecordNames(in: phoneB), [])
        _ = phoneA
    }

    func testNewerArrivingChangeReplacesTheLocalCopy() throws {
        let (context, children, _) = try makePhone()
        let remote = children[0].cloudRecord(in: zone)
        remote["name"] = "Maya"
        remote["modifiedAt"] = later

        try SyncApplier.apply([remote], deletions: [], to: context, calendar: london)
        XCTAssertEqual(children[0].name, "Maya")
        XCTAssertFalse(children[0].hasUnsyncedChanges)
    }

    func testAHabitGoingBackToEveryoneArrivesAsEveryone() throws {
        // CloudKit hands back an empty list as no value at all, as do records from older versions.
        let (context, _, habits) = try makePhone()
        habits[0].childIDs = [UUID()]
        let remote = habits[0].cloudRecord(in: zone)
        remote["childIDs"] = nil
        remote["modifiedAt"] = later

        try SyncApplier.apply([remote], deletions: [], to: context, calendar: london)
        XCTAssertEqual(habits[0].childIDs, [])
    }

    func testUnsentLocalChangeThatIsNewerWins() throws {
        let (context, children, _) = try makePhone()
        let remote = children[0].cloudRecord(in: zone)
        remote["name"] = "From the other phone"
        remote["modifiedAt"] = earlier.addingTimeInterval(60)
        children[0].name = "Changed here"
        children[0].touch(later)

        try SyncApplier.apply([remote], deletions: [], to: context, calendar: london)
        XCTAssertEqual(children[0].name, "Changed here")
        XCTAssertTrue(children[0].hasUnsyncedChanges) // still to upload, and will win
        XCTAssertNotNil(children[0].cloudSystemFields) // now carries the server's latest change tag
    }

    func testOlderLocalChangeLosesToANewerArrival() throws {
        let (context, children, _) = try makePhone()
        children[0].name = "Changed here first"
        children[0].touch(earlier.addingTimeInterval(60))
        let remote = children[0].cloudRecord(in: zone)
        remote["name"] = "Changed there later"
        remote["modifiedAt"] = later

        try SyncApplier.apply([remote], deletions: [], to: context, calendar: london)
        XCTAssertEqual(children[0].name, "Changed there later")
        XCTAssertFalse(children[0].hasUnsyncedChanges)
    }

    func testBothPhonesTickingTheSameBoxShareOneEntry() throws {
        let (phoneA, children, habits) = try makePhone()
        let phoneB = try makeContext()
        try SyncApplier.apply(records(children, habits), deletions: [], to: phoneB, calendar: london)
        let childB = try XCTUnwrap(phoneB.fetch(FetchDescriptor<Child>(sortBy: [SortDescriptor(\.sortOrder)])).first)
        let habitB = try XCTUnwrap(phoneB.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)])).first)

        let fromA = try DayEntry.upsert(child: children[0], habit: habits[0], date: day(2), status: .done, in: phoneA, calendar: london)
        fromA.touch(earlier)
        let fromB = try DayEntry.upsert(child: childB, habit: habitB, date: day(2), status: .missed, in: phoneB, calendar: london)
        fromB.touch(later)
        XCTAssertEqual(fromA.cloudRecordName, fromB.cloudRecordName)

        try SyncApplier.apply([fromB.cloudRecord(in: zone)], deletions: [], to: phoneA, calendar: london)
        let entries = try phoneA.fetch(FetchDescriptor<DayEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.status, .missed)
    }

    func testTicksAndPaymentsThatArriveBeforeTheirChildAreLinkedLater() throws {
        let (phoneA, children, habits) = try makePhone()
        let entry = try DayEntry.upsert(child: children[0], habit: habits[0], date: day(2), status: .done, in: phoneA, calendar: london)
        let payout = Payout.record(300, to: children[0], for: CalendarMonth(year: 2026, month: 9), paidOn: day(1), in: phoneA)
        let phoneB = try makeContext()

        try SyncApplier.apply(records([entry, payout]), deletions: [], to: phoneB, calendar: london)
        XCTAssertNil(try phoneB.fetch(FetchDescriptor<DayEntry>()).first?.child)

        try SyncApplier.apply(records(children, habits), deletions: [], to: phoneB, calendar: london)
        let entryB = try XCTUnwrap(phoneB.fetch(FetchDescriptor<DayEntry>()).first)
        XCTAssertEqual(entryB.child?.id, children[0].id)
        XCTAssertEqual(entryB.habit?.id, habits[0].id)
        XCTAssertEqual(try phoneB.fetch(FetchDescriptor<Payout>()).first?.child?.id, children[0].id)
    }

    func testDeletionsRemoveTheRecord() throws {
        let (context, children, _) = try makePhone()
        let payout = Payout.record(300, to: children[0], for: CalendarMonth(year: 2026, month: 9), paidOn: day(1), in: context)
        try context.save()

        try SyncApplier.apply([], deletions: [payout.cloudRecordName], to: context, calendar: london)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Payout>()), 0)
    }

    // MARK: - What still has to upload

    func testLocalChangesWaitToUploadUntilSent() throws {
        let (context, children, habits) = try makePhone()
        XCTAssertEqual(try SyncApplier.pendingRecordNames(in: context), [])

        let entry = try DayEntry.upsert(child: children[0], habit: habits[0], date: day(2), status: .done, in: context, calendar: london)
        children[1].name = "Leo"
        children[1].touch()
        try context.save()
        XCTAssertEqual(Set(try SyncApplier.pendingRecordNames(in: context)), [entry.cloudRecordName, children[1].cloudRecordName])

        let sent = entry.cloudRecord(in: zone)
        try SyncApplier.markSent([sent], in: context)
        XCTAssertEqual(try SyncApplier.pendingRecordNames(in: context), [children[1].cloudRecordName])
        XCTAssertNotNil(entry.cloudSystemFields)
    }

    func testAChangeMadeWhileUploadingStillUploads() throws {
        let (context, children, _) = try makePhone()
        children[0].touch(later)
        let sent = children[0].cloudRecord(in: zone)
        children[0].name = "Edited again"
        children[0].touch(later.addingTimeInterval(5))

        try SyncApplier.markSent([sent], in: context)
        XCTAssertEqual(try SyncApplier.pendingRecordNames(in: context), [children[0].cloudRecordName])
    }

    func testEverythingCanBeQueuedForTheFirstUpload() throws {
        let (context, children, habits) = try makePhone()
        try DayEntry.upsert(child: children[0], habit: habits[0], date: day(2), status: .done, in: context, calendar: london)
        try context.save()
        XCTAssertEqual(try SyncApplier.allRecordNames(in: context).count, children.count + habits.count + 1)
    }

    func testJoiningAFamilyClearsThisPhonesOwnData() throws {
        let (context, children, habits) = try makePhone()
        try DayEntry.upsert(child: children[0], habit: habits[0], date: day(2), status: .done, in: context, calendar: london)
        try context.save()

        try SyncApplier.deleteEverything(in: context)
        XCTAssertEqual(try SyncApplier.allRecordNames(in: context), [])
    }
}
