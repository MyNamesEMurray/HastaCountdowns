import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class CountdownStore {
    private(set) var countdowns: [Countdown] = []
    var saveError: String?

    private let isScreenshotMode: Bool
    @ObservationIgnored private(set) var sync: CloudSyncManager?

    init() {
        switch ScreenshotMode.current {
        case .samples, .homescreen, .lockscreen:
            countdowns = Countdown.samples
            isScreenshotMode = true
        case .empty, .welcome:
            countdowns = []
            isScreenshotMode = true
        case nil:
            countdowns = CountdownRepository.load()
            isScreenshotMode = false
            if !countdowns.isEmpty {
                BackgroundImageStore.removeUnreferenced(keeping: Set(countdowns.flatMap(\.allBackgroundImageIDs)))
            }
        }
        let sync = CloudSyncManager(store: self)
        self.sync = sync
        sync.start()
    }

    func countdown(with id: UUID) -> Countdown? {
        countdowns.first { $0.id == id }
    }

    func upcoming(at now: Date = .now) -> [Countdown] {
        countdowns.upcoming(at: now)
    }

    func past(at now: Date = .now) -> [Countdown] {
        countdowns.past(at: now)
    }

    func save(_ countdown: Countdown) {
        var countdown = countdown
        countdown.modifiedAt = .now
        if countdown.timeZoneIdentifier == nil {
            countdown.timeZoneIdentifier = TimeZone.current.identifier
        }
        if let index = countdowns.firstIndex(where: { $0.id == countdown.id }) {
            deleteImages(of: countdowns[index], keeping: countdown)
            countdowns[index] = countdown
        } else {
            countdowns.append(countdown)
        }
        persist()
        sync?.countdownSaved(countdown.id)
    }

    func duplicate(_ countdown: Countdown) {
        var copy = countdown
        copy.id = UUID()
        copy.title = String(localized: "\(countdown.displayTitle) Copy")
        copy.createdAt = .now
        copy.modifiedAt = .now
        copy.backgroundImageID = nil
        copy.extraBackgroundImageIDs = []
        copy.backgroundFraming = nil
        countdowns.append(copy)
        persist()
        sync?.countdownSaved(copy.id)
    }

    func delete(_ countdown: Countdown) {
        deleteImages(of: countdown, keeping: nil)
        countdowns.removeAll { $0.id == countdown.id }
        persist()
        sync?.countdownDeleted(countdown.id)
    }

    func applyRemoteChanges(upserts: [Countdown], deletions: [UUID]) {
        guard !upserts.isEmpty || !deletions.isEmpty else { return }
        for remote in upserts {
            if let index = countdowns.firstIndex(where: { $0.id == remote.id }) {
                deleteImages(of: countdowns[index], keeping: remote)
                countdowns[index] = remote
            } else {
                countdowns.append(remote)
            }
        }
        for id in deletions {
            if let existing = countdown(with: id) {
                deleteImages(of: existing, keeping: nil)
            }
            countdowns.removeAll { $0.id == id }
        }
        persist()
    }

    func reload() {
        guard !isScreenshotMode else { return }
        countdowns = CountdownRepository.load()
    }

    func refreshSideEffects() {
        WidgetCenter.shared.reloadAllTimelines()
        ReminderScheduler.reschedule(countdowns)
        LiveActivityManager.sync(countdowns, isPremium: Premium.isUnlocked)
        LiveActivityPushService.update(countdowns, isPremium: Premium.isUnlocked)
    }

    private func deleteImages(of old: Countdown, keeping new: Countdown?) {
        let kept = Set(new?.allBackgroundImageIDs ?? [])
        for id in old.allBackgroundImageIDs where !kept.contains(id) {
            BackgroundImageStore.delete(id)
        }
    }

    private func persist() {
        guard !isScreenshotMode else { return }
        do {
            try CountdownRepository.save(countdowns)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
            return
        }
        refreshSideEffects()
    }
}
