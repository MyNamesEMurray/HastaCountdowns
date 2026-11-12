import ActivityKit
import Foundation

@MainActor
enum LiveActivityPushService {
    static let endpoint = URL(string: "https://push.hasta.day/v1/schedule")!
    private static let registeredKey = "liveActivityPushRegistered"
    private static let horizon: TimeInterval = 30 * 86_400
    private static let maxCountdowns = 50

    private static var token: String?
    private static var latest: (countdowns: [Countdown], enabled: Bool) = ([], false)
    private static var lastSent: Data?
    private static var pending: Task<Void, Never>?
    private static var isListening = false

    private struct Payload: Encodable {
        struct Item: Encodable {
            let id: String
            let fireAt: Double
            let target: Double
        }

        let token: String
        let sandbox: Bool
        let countdowns: [Item]
    }

    static func update(_ countdowns: [Countdown], isPremium: Bool) {
        guard ScreenshotMode.current == nil, CloudSyncManager.isAllowedInThisProcess else { return }
        listenForToken()
        latest = (countdowns, isPremium && LiveActivityPreferences.pushEnabled && ActivityAuthorizationInfo().areActivitiesEnabled)
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await send()
        }
    }

    private static func listenForToken() {
        guard !isListening else { return }
        isListening = true
        Task {
            for await data in Activity<CountdownActivityAttributes>.pushToStartTokenUpdates {
                token = data.map { String(format: "%02x", $0) }.joined()
                lastSent = nil
                update(latest.countdowns, isPremium: latest.enabled)
            }
        }
    }

    private static func send() async {
        let defaults = AppGroup.defaults
        let wasRegistered = defaults.bool(forKey: registeredKey)
        guard latest.enabled || wasRegistered, let token else { return }

        let now = Date.now
        let lead = Double(LiveActivityPreferences.leadHours) * 3_600
        let items: [Payload.Item] = latest.enabled
            ? Array(latest.countdowns
                .map { ($0, $0.nextOccurrence(after: now)) }
                .filter { $0.1 > now && $0.1.timeIntervalSince(now) <= horizon }
                .sorted { $0.1 < $1.1 }
                .prefix(maxCountdowns)
                .map { countdown, target in
                    Payload.Item(id: countdown.id.uuidString, fireAt: target.timeIntervalSince1970 - lead, target: target.timeIntervalSince1970)
                })
            : []

        #if DEBUG
        let sandbox = true
        #else
        let sandbox = false
        #endif
        let payload = Payload(token: token, sandbox: sandbox, countdowns: items)
        guard let body = try? JSONEncoder().encode(payload), body != lastSent else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 20
        if let (_, response) = try? await URLSession.shared.data(for: request),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            lastSent = body
            defaults.set(latest.enabled, forKey: registeredKey)
        }
    }
}
