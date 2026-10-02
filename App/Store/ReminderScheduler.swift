import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "countdown-reminder-"
    private static let maximumPending = 60

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func reschedule(_ countdowns: [Countdown]) {
        let requests = makeRequests(for: countdowns, now: .now)
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let pending = await center.pendingNotificationRequests()
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            for request in requests {
                try? await center.add(request)
            }
        }
    }

    static func makeRequests(for countdowns: [Countdown], now: Date, calendar: Calendar = .current) -> [UNNotificationRequest] {
        let defaultTime = ReminderPreferences.time
        var scheduled: [(date: Date, request: UNNotificationRequest)] = []

        for countdown in countdowns where !countdown.reminders.isEmpty {
            for (index, target) in occurrences(of: countdown, after: now, calendar: calendar).enumerated() {
                for rule in countdown.reminders {
                    guard let date = rule.fireDate(for: target, isAllDay: countdown.isAllDay, defaultTime: defaultTime, calendar: calendar),
                          date > now else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = countdown.displayTitle
                    content.body = rule.notificationBody
                    content.sound = .default
                    content.userInfo = ["url": DeepLink.countdown(countdown.id).absoluteString]

                    let components = ReminderRule.triggerComponents(for: date, isAllDay: countdown.isAllDay, calendar: calendar)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let identifier = "\(identifierPrefix)\(countdown.id.uuidString)-\(rule.id.uuidString)-\(index)"
                    scheduled.append((date, UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)))
                }
            }
        }

        return scheduled
            .sorted { $0.date < $1.date }
            .prefix(maximumPending)
            .map(\.request)
    }

    private static func occurrences(of countdown: Countdown, after now: Date, calendar: Calendar) -> [Date] {
        let next = countdown.nextOccurrence(after: now, calendar: calendar)
        guard let component = countdown.repeatRule.calendarComponent,
              let following = calendar.date(byAdding: component, value: 1, to: next) else {
            return [next]
        }
        return [next, following]
    }
}
