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
    static let schemaVersion = 5
    static let imageFields = ["image", "extraImage0", "extraImage1", "extraImage2", "extraImage3"]
    private static let enabledKey = "iCloudSyncEnabled"

    static var isEnabledPreference: Bool {
        get { AppGroup.defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { AppGroup.defaults.set(newValue, forKey: enabledKey) }
    }

    static var isAllowedInThisProcess: Bool {
        ScreenshotMode.current == nil && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    private(set) var status: Status = .off
    private(set) var isEnabled = CloudSyncManager.isEnabledPreference

    @ObservationIgnored private weak var store: CountdownStore?
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var metadata = SyncMetadata.load()
    @ObservationIgnored private let zoneID = CKRecordZone.ID(zoneName: CloudSyncManager.zoneName)
    @ObservationIgnored private var needsRequeueAfterFetch = false

    init(store: CountdownStore) {
        self.store = store
    }

    private var container: CKContainer {
        CKContainer(identifier: Self.containerIdentifier)
    }

    func start() {
        if ScreenshotMode.current != nil, Self.isEnabledPreference {
            status = .upToDate(Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: .now) ?? .now)
            return
        }
        guard Self.isAllowedInThisProcess, Self.isEnabledPreference else {
            status = .off
            return
        }
        guard engine == nil else { return }
        status = .checking
        Task {
            let accountStatus = (try? await container.accountStatus()) ?? .couldNotDetermine
            guard Self.isEnabledPreference, engine == nil else { return }
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
        setPreference(enabled)
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
        setPreference(false)
        status = .off
    }

    private func setPreference(_ enabled: Bool) {
        Self.isEnabledPreference = enabled
        isEnabled = enabled
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
        metadata.imageSignatures?[id.uuidString] = nil
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
            await handleFetchedDatabaseChanges(changes)
        case .sentDatabaseChanges(let sent):
            if sent.savedZones.contains(where: { $0.zoneID == zoneID }) {
                markZoneConfirmed()
            }
        case .fetchedRecordZoneChanges(let changes):
            handleFetchedRecordZoneChanges(changes)
        case .sentRecordZoneChanges(let sent):
            handleSentRecordZoneChanges(sent)
        case .willFetchChanges, .willSendChanges:
            status = .syncing
        case .didFetchChanges:
            if needsRequeueAfterFetch {
                needsRequeueAfterFetch = false
                queueEverything(on: syncEngine)
            }
            markUpToDate()
        case .didSendChanges:
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
            metadata.imageSignatures = nil
            metadata.zoneConfirmed = nil
            metadata.save()
            if let engine { queueEverything(on: engine) }
        case .signOut:
            metadata.systemFields = [:]
            metadata.imageSignatures = nil
            metadata.save()
            status = .unavailable(String(localized: "Sign in to iCloud to sync your countdowns."))
        @unknown default:
            break
        }
    }

    private func handleFetchedDatabaseChanges(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges) async {
        guard changes.deletions.contains(where: { $0.zoneID == zoneID }), let engine else { return }
        let zoneExists = await zoneExistsOnServer()
        guard engine === self.engine else { return }
        if zoneExists != false || metadata.zoneConfirmed != true {
            metadata.systemFields = [:]
            metadata.imageSignatures = nil
            metadata.save()
            queueEverything(on: engine)
            needsRequeueAfterFetch = true
            return
        }
        self.engine = nil
        metadata = SyncMetadata()
        metadata.save()
        setPreference(false)
        status = .unavailable(String(localized: "Hasta's iCloud data was deleted. Turn iCloud Sync on again to upload this device's countdowns."))
    }

    private func zoneExistsOnServer() async -> Bool? {
        do {
            _ = try await container.privateCloudDatabase.recordZone(for: zoneID)
            return true
        } catch let error as CKError where error.code == .zoneNotFound {
            return false
        } catch {
            return nil
        }
    }

    private func markZoneConfirmed() {
        guard metadata.zoneConfirmed != true else { return }
        metadata.zoneConfirmed = true
        metadata.save()
    }

    private func handleFetchedRecordZoneChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        guard let store else { return }
        var upserts: [Countdown] = []
        var requeue: [UUID] = []
        let pendingDeletes = Set((engine?.state.pendingRecordZoneChanges ?? []).compactMap { change -> String? in
            if case .deleteRecord(let id) = change { return id.recordName }
            return nil
        })
        for modification in changes.modifications {
            let record = modification.record
            guard !pendingDeletes.contains(record.recordID.recordName) else { continue }
            guard let decoded = countdown(from: record) else { continue }
            let (remote, needsPush) = reconciled(decoded, from: record)
            metadata.systemFields[record.recordID.recordName] = encodedSystemFields(of: record)
            if let local = store.countdown(with: remote.id), local.supersedes(remote) {
                requeue.append(local.id)
                continue
            }
            importImages(from: record, for: remote)
            upserts.append(remote)
            if needsPush { requeue.append(remote.id) }
        }
        if !changes.modifications.isEmpty {
            metadata.zoneConfirmed = true
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
            if let signature = record["imageSig"] as? String {
                metadata.setSignature(signature, for: record.recordID.recordName)
            }
        }
        if !sent.savedRecords.isEmpty {
            metadata.zoneConfirmed = true
        }
        for failure in sent.failedRecordSaves {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failure.error.serverRecord else { continue }
                metadata.systemFields[recordID.recordName] = encodedSystemFields(of: serverRecord)
                if let decoded = countdown(from: serverRecord),
                   let local = store?.countdown(with: decoded.id),
                   decoded.supersedes(local) {
                    let (remote, needsPush) = reconciled(decoded, from: serverRecord)
                    importImages(from: serverRecord, for: remote)
                    store?.applyRemoteChanges(upserts: [remote], deletions: [])
                    if needsPush { engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)]) }
                } else {
                    engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
                }
            case .zoneNotFound:
                engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            case .unknownItem:
                metadata.systemFields[recordID.recordName] = nil
                metadata.imageSignatures?[recordID.recordName] = nil
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
        record["schema"] = Self.schemaVersion
        let slots = countdown.backgroundImageSlots.map { id in
            id.flatMap { FileManager.default.fileExists(atPath: BackgroundImageStore.url(for: $0).path()) ? $0 : nil }
        }
        let signature = slots.map { $0 ?? "" }.joined(separator: ",")
        if metadata.imageSignatures?[recordID.recordName] != signature {
            record["imageSig"] = signature
            for (field, id) in zip(Self.imageFields, slots) {
                record[field] = id.map { CKAsset(fileURL: BackgroundImageStore.url(for: $0)) }
            }
        }
        return record
    }

    private func countdown(from record: CKRecord) -> Countdown? {
        guard let payload = record["payload"] as? Data else { return nil }
        return try? Self.decoder.decode(Countdown.self, from: payload)
    }

    private func importImages(from record: CKRecord, for countdown: Countdown) {
        for (field, id) in zip(Self.imageFields, countdown.backgroundImageSlots) {
            guard let id, let source = (record[field] as? CKAsset)?.fileURL else { continue }
            let destination = BackgroundImageStore.url(for: id)
            guard !FileManager.default.fileExists(atPath: destination.path()) else { continue }
            try? FileManager.default.copyItem(at: source, to: destination)
        }
        if let signature = record["imageSig"] as? String {
            metadata.setSignature(signature, for: record.recordID.recordName)
        }
    }

    private func reconciled(_ remote: Countdown, from record: CKRecord) -> (countdown: Countdown, needsPush: Bool) {
        guard (record["schema"] as? Int ?? 1) < Self.schemaVersion,
              let local = store?.countdown(with: remote.id) else { return (remote, false) }
        var merged = remote
        merged.keepNewFields(from: local)
        return (merged, true)
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
        case .noAccount: String(localized: "Sign in to iCloud to sync your countdowns.")
        case .restricted: String(localized: "iCloud is restricted on this device.")
        case .temporarilyUnavailable: String(localized: "iCloud is temporarily unavailable.")
        default: String(localized: "iCloud isn't available right now.")
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
    var zoneConfirmed: Bool?
    var imageSignatures: [String: String]?

    mutating func setSignature(_ signature: String, for name: String) {
        var all = imageSignatures ?? [:]
        all[name] = signature
        imageSignatures = all
    }

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
