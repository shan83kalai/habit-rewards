import CloudKit
import Foundation
import Observation
import SwiftData
import WidgetKit

/// Shares the family's data between the parents' phones through iCloud.
///
/// The parent who starts sharing (the owner) keeps a "Family" zone in their private iCloud
/// database and shares the whole zone; the other parent accepts and sees it in their shared
/// database. Each phone runs a `CKSyncEngine` against its side, with its own SwiftData store as
/// the working copy. `SyncApplier` does the merging; this class does the CloudKit plumbing.
@Observable
final class FamilySync {
    static let shared = FamilySync()
    static let containerIdentifier = "iCloud.ltd.kalai.HabitRewards"
    static let zoneName = "Family"

    enum Role: Codable, Equatable {
        case off
        /// This phone started sharing: the zone is in its private database.
        case owner
        /// This phone joined: the zone belongs to `ownerName` (a CloudKit user record name) and is in its shared database.
        case participant(ownerName: String, ownerDisplayName: String?)
    }

    enum Status: Equatable {
        case idle
        case syncing
        case synced(Date)
        case problem(String)
    }

    enum SyncError: LocalizedError {
        case noAccount
        case alreadySharing

        var errorDescription: String? {
            switch self {
            case .noAccount: String(localized: "Sign in to iCloud in the Settings app first.")
            case .alreadySharing: String(localized: "This phone is already sharing a family. Stop sharing first.")
            }
        }
    }

    private(set) var role: Role = .off
    private(set) var status: Status = .idle
    /// An invitation the parent has opened, waiting for them to confirm joining.
    var pendingInvite: CKShare.Metadata?
    /// Shown once when sharing ends from the other side (or the iCloud account changes).
    var notice: String?

    @ObservationIgnored private var modelContainer: ModelContainer?
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var engineDelegate: EngineDelegate?
    @ObservationIgnored private var engineState: CKSyncEngine.State.Serialization?
    /// Where `syncNow` last read the family zone up to.
    @ObservationIgnored private var pollToken: CKServerChangeToken?
    @ObservationIgnored private var changesObserver: NSObjectProtocol?
    @ObservationIgnored private(set) lazy var container = CKContainer(identifier: Self.containerIdentifier)

    var isSharing: Bool { role != .off }

    var zoneID: CKRecordZone.ID? {
        switch role {
        case .off: nil
        case .owner: CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
        case .participant(let ownerName, _): CKRecordZone.ID(zoneName: Self.zoneName, ownerName: ownerName)
        }
    }

    private var context: ModelContext? { modelContainer?.mainContext }

    // MARK: - Lifecycle

    /// Resumes syncing if this phone was sharing. Call once at launch; never in tests.
    func start(with modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let saved = Self.loadSaved()
        role = saved.role
        engineState = saved.engineState
        pollToken = saved.pollToken.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0) }
        changesObserver = NotificationCenter.default.addObserver(forName: LocalChanges.didSave, object: nil, queue: .main) { note in
            let deleted = note.userInfo?[LocalChanges.deletedKey] as? [String] ?? []
            MainActor.assumeIsolated { FamilySync.shared.queueLocalChanges(deleted: deleted) }
        }
        if isSharing { startEngine() }
    }

    private func startEngine() {
        let database = role == .owner ? container.privateCloudDatabase : container.sharedCloudDatabase
        let delegate = EngineDelegate(sync: self)
        engineDelegate = delegate
        engine = CKSyncEngine(CKSyncEngine.Configuration(database: database, stateSerialization: engineState, delegate: delegate))
        queueLocalChanges(deleted: [])
    }

    private func stopEngine() {
        engine = nil
        engineDelegate = nil
        engineState = nil
        pollToken = nil
    }


    // MARK: - Owner: start sharing

    /// Creates the family zone and its share, then uploads everything on this phone.
    /// Returns the share, for the invite sheet. Calling it again returns the existing share.
    func startSharing() async throws -> CKShare {
        if case .participant = role { throw SyncError.alreadySharing }
        guard try await container.accountStatus() == .available else { throw SyncError.noAccount }

        let database = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: Self.zoneName)
        _ = try await database.modifyRecordZones(saving: [zone], deleting: [])

        let share: CKShare
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone.zoneID)
        if let existing = try? await database.record(for: shareID) as? CKShare {
            share = existing
        } else {
            let new = CKShare(recordZoneID: zone.zoneID)
            new[CKShare.SystemFieldKey.title] = String(localized: "Habit Rewards family")
            new.publicPermission = .none
            let saved = try await database.modifyRecords(saving: [new], deleting: [])
            share = (try saved.saveResults[new.recordID]?.get() as? CKShare) ?? new
        }

        if role != .owner {
            role = .owner
            save()
            startEngine()
            // First upload: everything this phone has.
            if let context, let zoneID, let names = try? SyncApplier.allRecordNames(in: context) {
                engine?.state.add(pendingRecordZoneChanges: names.map { .saveRecord(CKRecord.ID(recordName: $0, zoneID: zoneID)) })
            }
        }
        return share
    }

    /// Ends sharing for everyone (owner) or leaves the family (participant). This phone keeps its copy.
    func stopSharing() async throws {
        guard let zoneID else { return }
        switch role {
        case .off:
            return
        case .owner:
            // Deleting the zone deletes its share too, so the other parent loses access.
            _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
        case .participant:
            _ = try await container.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
        }
        endSharingLocally(notice: nil)
    }

    /// The owner stopped sharing from the invite sheet, which removes the share but leaves the zone.
    func ownerStoppedSharing() {
        if let zoneID {
            let database = container.privateCloudDatabase
            Task { _ = try? await database.modifyRecordZones(saving: [], deleting: [zoneID]) }
        }
        endSharingLocally(notice: nil)
    }

    private func endSharingLocally(notice: String?) {
        stopEngine()
        role = .off
        status = .idle
        self.notice = notice
        if let context { try? SyncApplier.forgetCloudState(in: context) }
        save()
    }

    // MARK: - Participant: join

    /// An invitation link was opened. The parent confirms before anything changes.
    func receivedInvite(_ metadata: CKShare.Metadata) {
        guard metadata.containerIdentifier == Self.containerIdentifier else { return }
        pendingInvite = metadata
    }

    /// Accepts the invitation and replaces this phone's own data with the family's.
    func join(_ metadata: CKShare.Metadata) async throws {
        if role == .owner { throw SyncError.alreadySharing }
        _ = try await container.accept(metadata)
        if let context { try SyncApplier.deleteEverything(in: context) }

        let ownerName = metadata.share.recordID.zoneID.ownerName
        let displayName = metadata.ownerIdentity.nameComponents.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
        stopEngine()
        role = .participant(ownerName: ownerName, ownerDisplayName: displayName)
        pendingInvite = nil
        save()
        startEngine()
        try await engine?.fetchChanges()
    }

    /// Sends and fetches straight away (pull-to-refresh, coming to the front, the minute check).
    func syncNow() async {
        guard isSharing else { return }
        try? await engine?.sendChanges()
        try? await engine?.fetchChanges()
        // While the app is open, CKSyncEngine only goes to iCloud when a push says something
        // changed, and pushes can be late (simulators never get them). So also read the family
        // zone's changes directly. Merging is idempotent, so anything the engine later delivers
        // again changes nothing.
        do {
            try await fetchFamilyZoneDirectly()
        } catch let error as CKError where [.zoneNotFound, .userDeletedZone].contains(error.code) {
            endSharingLocally(notice: String(localized: "Family sharing stopped. This phone keeps its copy of everything."))
        } catch {
            status = .problem(error.localizedDescription)
        }
    }

    /// Everything that changed in the family zone since this phone last looked, using a change
    /// token of its own (separate from the engine's).
    private func fetchFamilyZoneDirectly() async throws {
        guard let zoneID, let context else { return }
        let database = role == .owner ? container.privateCloudDatabase : container.sharedCloudDatabase
        var token = pollToken
        var moreComing = true
        while moreComing {
            let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
            let records = changes.modificationResultsByID.values.compactMap { try? $0.get().record }
            try SyncApplier.apply(records, deletions: changes.deletions.map(\.recordID.recordName), to: context)
            if !records.isEmpty || !changes.deletions.isEmpty {
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetCenter.todayKind)
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        pollToken = token
        status = .synced(.now)
        save()
    }

    // MARK: - Local changes

    /// Queues everything changed on this phone (and anything deleted) for upload.
    func queueLocalChanges(deleted: [String]) {
        guard let engine, let zoneID, let context else { return }
        let names = (try? SyncApplier.pendingRecordNames(in: context)) ?? []
        let changes: [CKSyncEngine.PendingRecordZoneChange] =
            names.map { .saveRecord(CKRecord.ID(recordName: $0, zoneID: zoneID)) }
            + deleted.map { .deleteRecord(CKRecord.ID(recordName: $0, zoneID: zoneID)) }
        if !changes.isEmpty {
            engine.state.add(pendingRecordZoneChanges: changes)
        }
    }

    // MARK: - Engine events

    fileprivate func handle(_ event: CKSyncEngine.Event, from syncEngine: CKSyncEngine) {
        // Ignore late events from an engine that has since been replaced (e.g. after leaving and rejoining).
        guard let context, syncEngine === engine else { return }
        do {
            switch event {
            case .stateUpdate(let update):
                engineState = update.stateSerialization
                save()

            case .accountChange(let change):
                switch change.changeType {
                case .signIn: break
                case .signOut, .switchAccounts:
                    endSharingLocally(notice: String(localized: "The iCloud account changed, so family sharing stopped. This phone keeps its copy."))
                @unknown default: break
                }

            case .fetchedDatabaseChanges(let changes):
                if let zoneID, changes.deletions.contains(where: { $0.zoneID == zoneID }) {
                    endSharingLocally(notice: String(localized: "Family sharing stopped. This phone keeps its copy of everything."))
                }

            case .fetchedRecordZoneChanges(let changes):
                try SyncApplier.apply(
                    changes.modifications.map(\.record),
                    deletions: changes.deletions.map(\.recordID.recordName),
                    to: context
                )
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetCenter.todayKind)

            case .sentRecordZoneChanges(let sent):
                try SyncApplier.markSent(sent.savedRecords, in: context)
                try handleFailedSaves(sent.failedRecordSaves, in: context)

            case .willFetchChanges, .willSendChanges:
                status = .syncing

            case .didFetchChanges, .didSendChanges:
                status = .synced(.now)

            default:
                break
            }
        } catch {
            status = .problem(error.localizedDescription)
        }
    }

    private func handleFailedSaves(_ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave], in context: ModelContext) throws {
        guard let engine else { return }
        for failure in failures {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                // Someone else changed it first: merge theirs (newer wins), then send ours again if it still wins.
                if let server = failure.error.serverRecord {
                    try SyncApplier.apply([server], deletions: [], to: context)
                }
                if try SyncApplier.model(named: recordID.recordName, in: context)?.hasUnsyncedChanges == true {
                    engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                }
            case .zoneNotFound where role == .owner:
                // The zone went missing (e.g. iCloud data was reset): recreate it and try again.
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: recordID.zoneID))])
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            case .unknownItem:
                // The server no longer has this record: send it fresh.
                try SyncApplier.model(named: recordID.recordName, in: context)?.cloudSystemFields = nil
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            default:
                status = .problem(failure.error.localizedDescription)
            }
        }
    }

    fileprivate func nextBatch(_ sendContext: CKSyncEngine.SendChangesContext, engine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard engine === self.engine else { return nil }
        let pending = engine.state.pendingRecordZoneChanges.filter { sendContext.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            await self.record(for: recordID)
        }
    }

    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let context else { return nil }
        return try? SyncApplier.record(named: recordID.recordName, zone: recordID.zoneID, in: context)
    }

    // MARK: - Saved state

    private struct Saved: Codable {
        var role: Role = .off
        var engineState: CKSyncEngine.State.Serialization?
        var pollToken: Data?
    }

    /// Per phone, outside the shared App Group: the widget never needs it.
    private static var savedURL: URL {
        URL.applicationSupportDirectory.appending(path: "FamilySync.json")
    }

    private static func loadSaved() -> Saved {
        guard let data = try? Data(contentsOf: savedURL), let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return Saved() }
        return saved
    }

    private func save() {
        let token = pollToken.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
        let saved = Saved(role: role, engineState: engineState, pollToken: token)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? FileManager.default.createDirectory(at: Self.savedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.savedURL, options: .atomic)
    }
}

/// CKSyncEngine calls its delegate off the main actor; this hands each call to `FamilySync` there.
private nonisolated final class EngineDelegate: CKSyncEngineDelegate, Sendable {
    let sync: FamilySync

    init(sync: FamilySync) {
        self.sync = sync
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await sync.handle(event, from: syncEngine)
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await sync.nextBatch(context, engine: syncEngine)
    }
}
