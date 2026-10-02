import ActivityKit
import Foundation

@MainActor
enum LiveActivityManager {
    static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func isActive(for id: UUID) -> Bool {
        Activity<CountdownActivityAttributes>.activities.contains {
            $0.attributes.countdownID == id && $0.activityState == .active
        }
    }

    static func start(for countdown: Countdown) throws {
        let content = ActivityContent(
            state: CountdownActivityAttributes.ContentState(countdown: countdown.resolved(isPremium: Premium.isUnlocked)),
            staleDate: countdown.nextOccurrence()
        )
        _ = try Activity.request(
            attributes: CountdownActivityAttributes(countdownID: countdown.id),
            content: content,
            pushType: nil
        )
    }

    static func stop(for id: UUID) async {
        for activity in Activity<CountdownActivityAttributes>.activities where activity.attributes.countdownID == id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func sync(with countdowns: [Countdown]) async {
        for activity in Activity<CountdownActivityAttributes>.activities {
            guard let countdown = countdowns.first(where: { $0.id == activity.attributes.countdownID }) else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            let state = CountdownActivityAttributes.ContentState(countdown: countdown.resolved(isPremium: Premium.isUnlocked))
            guard state != activity.content.state else { continue }
            await activity.update(ActivityContent(state: state, staleDate: countdown.nextOccurrence()))
        }
    }
}
