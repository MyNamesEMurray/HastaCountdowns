import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class CountdownStore {
    private(set) var countdowns: [Countdown] = []

    private let isScreenshotMode: Bool

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
    }

    func duplicate(_ countdown: Countdown) {
        var copy = countdown
        copy.id = UUID()
        copy.title = "\(countdown.displayTitle) Copy"
        copy.createdAt = .now
        copy.backgroundImageID = nil
        countdowns.append(copy)
        persist()
    }

    func delete(_ countdown: Countdown) {
        if let imageID = countdown.backgroundImageID {
            BackgroundImageStore.delete(imageID)
        }
        countdowns.removeAll { $0.id == countdown.id }
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
