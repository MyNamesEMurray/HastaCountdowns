import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    static let window: TimeInterval = 86_400
    static let maxActivities = 3

    static func sync(_ countdowns: [Countdown], isPremium: Bool, now: Date = .now) {
        guard ScreenshotMode.current == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        var wanted: [UUID: CountdownActivityAttributes.ContentState] = [:]
        if isPremium {
            let due = countdowns
                .map { ($0, $0.nextOccurrence(after: now)) }
                .filter { $0.1 > now && $0.1.timeIntervalSince(now) <= window }
                .sorted { $0.1 < $1.1 }
                .prefix(maxActivities)
            for (countdown, target) in due {
                wanted[countdown.id] = .init(
                    title: countdown.displayTitle,
                    symbol: countdown.symbol,
                    tintHex: countdown.tint.hexString ?? "#0A84FF",
                    start: now,
                    target: target
                )
            }
        }

        var running: Set<UUID> = []
        for activity in Activity<CountdownActivityAttributes>.activities {
            let id = activity.attributes.countdownID
            guard var state = wanted[id] else {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
                continue
            }
            running.insert(id)
            state.start = activity.content.state.start
            if state != activity.content.state {
                Task { await activity.update(.init(state: state, staleDate: state.target)) }
            }
        }

        for (id, state) in wanted where !running.contains(id) {
            _ = try? Activity.request(
                attributes: CountdownActivityAttributes(countdownID: id),
                content: .init(state: state, staleDate: state.target),
                pushType: nil
            )
        }
    }
}
