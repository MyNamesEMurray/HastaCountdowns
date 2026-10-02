import CloudKit
import Foundation
import Observation

@MainActor
@Observable
final class CloudSyncManager: CKSyncEngineDelegate {
    enum Status: Equatable {
        case off
        case checking
        case unavailable(String)
        case syncing
        case upToDate(Date)
        case failed(String)
    }

    static let containerIdentifier = "iCloud.com.exaltedpixels.Hasta"
    static let recordType = "Countdown"
    static let zoneName = "Countdowns"
    private static let enabledKey = "iCloudSyncEnabled"

    static var isEnabledPreference: Bool {
        get { AppGroup.defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { AppGroup.defaults.set(newValue, forKey: enabledKey) }
    }

    static var isAllowedInThisProcess: Bool {
        ScreenshotMode.current == nil && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    private(set) var status: Status = .off

    @ObservationIgnored private weak var store: CountdownStore?
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var metadata = SyncMetadata.load()
    @ObservationIgnored private let zoneID = CKRecordZone.ID(zoneName: CloudSyncManager.zoneName)

    init(store: CountdownStore) {
        self.store = store
    }

    private var container: CKContainer {
        CKContainer(identifier: Self.containerIdentifier)
    }

    func start() {
        guard Self.isAllowedInThisProcess, Self.isEnabledPreference else {
            status = .off
            return
        }
        guard engine == nil else { return }
        status = .checking
        Task {
            let accountStatus = (try? await container.accountStatus()) ?? .couldNotDetermine
            guard accountStatus == .available else {
                status = .unavailable(Self.message(for: accountStatus))
                return
            }
            startEngine()
            await fetchChanges()
        }
    }

    func stop() {
        engine = nil
        status = .off
    }

    func setEnabled(_ enabled: Bool) {
        Self.isEnabledPreference = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func deleteCloudData() async throws {
        engine = nil
        status = .syncing
        do {
            _ = try await container.privateCloudDatabase.deleteRecordZone(withID: zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
        } catch {
            start()
            throw error
        }
        metadata = SyncMetadata()
        metadata.save()
        Self.isEnabledPreference = false
        status = .off
    }

    func fetchChanges() async {
        guard let engine else { return }
        status = .syncing
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
            markUpToDate()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func countdownSaved(_ id: UUID) {
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID(for: id))])
    }

    func countdownDeleted(_ id: UUID) {
        guard let engine else { return }
        metadata.systemFields[id.uuidString] = nil
        metadata.save()
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID(for: id))])
    }

    // MARK: - CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard syncEngine === engine else { return }
        switch event {
        case .stateUpdate(let update):
            metadata.stateSerialization = update.stateSerialization
            metadata.save()
        case .accountChange(let change):
            handleAccountChange(change)
        case .fetchedDatabaseChanges(let changes):
            handleFetchedDatabaseChanges(changes)
        case .fetchedRecordZoneChanges(let changes):
            handleFetchedRecordZoneChanges(changes)
        case .sentRecordZoneChanges(let sent):
            handleSentRecordZoneChanges(sent)
        case .willFetchChanges, .willSendChanges:
            status = .syncing
        case .didFetchChanges, .didSendChanges:
            markUpToDate()
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard syncEngine === engine else { return nil }
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !changes.isEmpty else { return nil }
        var records: [CKRecord.ID: CKRecord] = [:]
        var missing: [CKSyncEngine.PendingRecordZoneChange] = []
        for change in changes {
            guard case .saveRecord(let recordID) = change else { continue }
            if let id = UUID(uuidString: recordID.recordName), let countdown = store?.countdown(with: id) {
                records[recordID] = record(for: countdown)
            } else {
                missing.append(change)
            }
        }
        if !missing.isEmpty {
            syncEngine.state.remove(pendingRecordZoneChanges: missing)
        }
        let provided = records
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes.filter { !missing.contains($0) }) { recordID in
            provided[recordID]
        }
    }

    // MARK: - Engine

    private func startEngine() {
        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: metadata.stateSerialization,
            delegate: self
        )
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        if metadata.stateSerialization == nil {
            queueEverything(on: engine)
        }
    }

    private func queueEverything(on engine: CKSyncEngine) {
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        let saves = (store?.countdowns ?? []).map { CKSyncEngine.PendingRecordZoneChange.saveRecord(recordID(for: $0.id)) }
        engine.state.add(pendingRecordZoneChanges: saves)
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn, .switchAccounts:
            metadata.systemFields = [:]
            metadata.save()
            if let engine { queueEverything(on: engine) }
        case .signOut:
            metadata.systemFields = [:]
            metadata.save()
            status = .unavailable("Sign in to iCloud to sync your countdowns.")
        @unknown default:
            break
        }
    }

    private func handleFetchedDatabaseChanges(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges) {
        guard changes.deletions.contains(where: { $0.zoneID == zoneID }) else { return }
        engine = nil
        metadata = SyncMetadata()
        metadata.save()
        Self.isEnabledPreference = false
        status = .unavailable("Hasta's iCloud data was deleted. Turn iCloud Sync on again to upload this device's countdowns.")
    }

    private func handleFetchedRecordZoneChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        guard let store else { return }
        var upserts: [Countdown] = []
        var requeue: [UUID] = []
        for modification in changes.modifications {
            let record = modification.record
            guard let remote = countdown(from: record) else { continue }
            metadata.systemFields[record.recordID.recordName] = encodedSystemFields(of: record)
            if let local = store.countdown(with: remote.id), local.modifiedAt > remote.modifiedAt {
                requeue.append(local.id)
                continue
            }
            importImage(from: record, for: remote)
            upserts.append(remote)
        }
        let deletions = changes.deletions.compactMap { UUID(uuidString: $0.recordID.recordName) }
        for id in deletions {
            metadata.systemFields[id.uuidString] = nil
        }
        metadata.save()
        store.applyRemoteChanges(upserts: upserts, deletions: deletions)
        requeue.forEach(countdownSaved)
    }

    private func handleSentRecordZoneChanges(_ sent: CKSyncEngine.Event.SentRecordZoneChanges) {
        for record in sent.savedRecords {
            metadata.systemFields[record.recordID.recordName] = encodedSystemFields(of: record)
        }
        for failure in sent.failedRecordSaves {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failure.error.serverRecord else { continue }
                metadata.systemFields[recordID.recordName] = encodedSystemFields(of: serverRecord)
                if let remote = countdown(from: serverRecord),
                   let local = store?.countdown(with: remote.id),
                   remote.modifiedAt > local.modifiedAt {
                    importImage(from: serverRecord, for: remote)
                    store?.applyRemoteChanges(upserts: [remote], deletions: [])
                } else {
                    engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                }
            case .zoneNotFound:
                engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            case .unknownItem:
                metadata.systemFields[recordID.recordName] = nil
                engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable, .notAuthenticated, .operationCancelled, .requestRateLimited:
                break
            default:
                status = .failed(failure.error.localizedDescription)
            }
        }
        metadata.save()
    }

    private func markUpToDate() {
        guard engine != nil else { return }
        status = .upToDate(.now)
    }

    // MARK: - Records

    private func recordID(for id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
    }

    private func record(for countdown: Countdown) -> CKRecord {
        let recordID = recordID(for: countdown.id)
        let record = restoredRecord(named: recordID.recordName) ?? CKRecord(recordType: Self.recordType, recordID: recordID)
        record["payload"] = try? Self.encoder.encode(countdown)
        record["modifiedAt"] = countdown.modifiedAt
        if let imageID = countdown.backgroundImageID,
           FileManager.default.fileExists(atPath: BackgroundImageStore.url(for: imageID).path()) {
            record["image"] = CKAsset(fileURL: BackgroundImageStore.url(for: imageID))
        } else {
            record["image"] = nil
        }
        return record
    }

    private func countdown(from record: CKRecord) -> Countdown? {
        guard let payload = record["payload"] as? Data else { return nil }
        return try? Self.decoder.decode(Countdown.self, from: payload)
    }

    private func importImage(from record: CKRecord, for countdown: Countdown) {
        guard let imageID = countdown.backgroundImageID,
              let asset = record["image"] as? CKAsset,
              let source = asset.fileURL else { return }
        let destination = BackgroundImageStore.url(for: imageID)
        guard !FileManager.default.fileExists(atPath: destination.path()) else { return }
        try? FileManager.default.copyItem(at: source, to: destination)
    }

    private func restoredRecord(named name: String) -> CKRecord? {
        guard let data = metadata.systemFields[name],
              let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }

    private func encodedSystemFields(of record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    private static func message(for status: CKAccountStatus) -> String {
        switch status {
        case .noAccount: "Sign in to iCloud to sync your countdowns."
        case .restricted: "iCloud is restricted on this device."
        case .temporarilyUnavailable: "iCloud is temporarily unavailable."
        default: "iCloud isn't available right now."
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

struct SyncMetadata: Codable {
    var stateSerialization: CKSyncEngine.State.Serialization?
    var systemFields: [String: Data] = [:]

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "CloudSync.json")
    }

    static func load() -> SyncMetadata {
        guard let data = try? Data(contentsOf: fileURL),
              let metadata = try? JSONDecoder().decode(SyncMetadata.self, from: data) else { return SyncMetadata() }
        return metadata
    }

    func save() {
        let url = Self.fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
