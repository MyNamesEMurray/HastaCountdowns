import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    nonisolated static let maxActivities = 3
    private static let dismissedKey = "liveActivityDismissed"
    private static var ending: Set<UUID> = []
    private static var observed: Set<String> = []

    nonisolated static func due(_ countdowns: [Countdown], now: Date, window: TimeInterval) -> [(Countdown, Date)] {
        let upcoming = countdowns
            .map { ($0, $0.nextOccurrence(after: now)) }
            .filter { $0.1 > now && $0.1.timeIntervalSince(now) <= window }
            .sorted { $0.1 < $1.1 }
        return Array(upcoming.prefix(maxActivities))
    }

    static func sync(_ countdowns: [Countdown], isPremium: Bool, now: Date = .now) {
        guard ScreenshotMode.current == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        var wanted: [UUID: CountdownActivityAttributes.ContentState] = [:]
        if isPremium {
            let window = Double(LiveActivityPreferences.leadHours) * 3_600
            for (countdown, target) in due(countdowns, now: now, window: window)
            where !isDismissed(countdown.id, target) {
                wanted[countdown.id] = .init(start: now, target: target, revision: countdown.modifiedAt.timeIntervalSince1970)
            }
        }

        var running: Set<UUID> = []
        for activity in Activity<CountdownActivityAttributes>.activities {
            let id = activity.attributes.countdownID
            observe(activity)
            guard var state = wanted[id] else {
                ending.insert(id)
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    ending.remove(id)
                }
                continue
            }
            running.insert(id)
            state.start = activity.content.state.start
            if state != activity.content.state {
                Task { await activity.update(.init(state: state, staleDate: state.target)) }
            }
        }

        for (id, state) in wanted where !running.contains(id) {
            if let activity = try? Activity.request(
                attributes: CountdownActivityAttributes(countdownID: id),
                content: .init(state: state, staleDate: state.target),
                pushType: nil
            ) {
                observe(activity)
            }
        }
    }

    private static func key(_ id: UUID, _ target: Date) -> String {
        "\(id.uuidString)|\(Int(target.timeIntervalSince1970))"
    }

    private static func isDismissed(_ id: UUID, _ target: Date) -> Bool {
        AppGroup.defaults.stringArray(forKey: dismissedKey)?.contains(key(id, target)) == true
    }

    // A swipe-away by the user is remembered so sync does not bring the activity back.
    private static func observe(_ activity: Activity<CountdownActivityAttributes>) {
        guard observed.insert(activity.id).inserted else { return }
        Task {
            for await state in activity.activityStateUpdates where state == .dismissed {
                let id = activity.attributes.countdownID
                guard !ending.contains(id) else { break }
                var all = AppGroup.defaults.stringArray(forKey: dismissedKey) ?? []
                all.append(key(id, activity.content.state.target))
                AppGroup.defaults.set(Array(all.suffix(50)), forKey: dismissedKey)
                break
            }
            observed.remove(activity.id)
        }
    }
}
