import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class CountdownStore {
    private(set) var countdowns: [Countdown] = []

    init() {
        countdowns = CountdownRepository.load()
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
        countdowns = CountdownRepository.load()
    }

    func refreshSideEffects() {
        WidgetCenter.shared.reloadAllTimelines()
        ReminderScheduler.reschedule(countdowns)
    }

    private func persist() {
        do {
            try CountdownRepository.save(countdowns)
        } catch {
            assertionFailure("Failed to save countdowns: \(error)")
        }
        refreshSideEffects()
    }
}
