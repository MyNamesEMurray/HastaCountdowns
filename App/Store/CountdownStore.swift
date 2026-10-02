import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class CountdownStore {
    private(set) var countdowns: [Countdown] = []

    private let isScreenshotMode: Bool
    @ObservationIgnored private(set) var sync: CloudSyncManager?

    init() {
        switch ScreenshotMode.current {
        case .samples:
            countdowns = Countdown.samples
            isScreenshotMode = true
        case .empty, .welcome:
            countdowns = []
            isScreenshotMode = true
        case nil:
            countdowns = CountdownRepository.load()
            isScreenshotMode = false
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
            let previousImage = countdowns[index].backgroundImageID
            if let previousImage, previousImage != countdown.backgroundImageID {
                BackgroundImageStore.delete(previousImage)
            }
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
        copy.title = "\(countdown.displayTitle) Copy"
        copy.createdAt = .now
        copy.modifiedAt = .now
        copy.backgroundImageID = nil
        copy.backgroundFraming = nil
        countdowns.append(copy)
        persist()
        sync?.countdownSaved(copy.id)
    }

    func delete(_ countdown: Countdown) {
        if let imageID = countdown.backgroundImageID {
            BackgroundImageStore.delete(imageID)
        }
        countdowns.removeAll { $0.id == countdown.id }
        persist()
        sync?.countdownDeleted(countdown.id)
    }

    func applyRemoteChanges(upserts: [Countdown], deletions: [UUID]) {
        guard !upserts.isEmpty || !deletions.isEmpty else { return }
        for remote in upserts {
            if let index = countdowns.firstIndex(where: { $0.id == remote.id }) {
                let previousImage = countdowns[index].backgroundImageID
                if let previousImage, previousImage != remote.backgroundImageID {
                    BackgroundImageStore.delete(previousImage)
                }
                countdowns[index] = remote
            } else {
                countdowns.append(remote)
            }
        }
        for id in deletions {
            if let imageID = countdown(with: id)?.backgroundImageID {
                BackgroundImageStore.delete(imageID)
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
    }

    private func persist() {
        guard !isScreenshotMode else { return }
        do {
            try CountdownRepository.save(countdowns)
        } catch {
            assertionFailure("Failed to save countdowns: \(error)")
        }
        refreshSideEffects()
    }
}
