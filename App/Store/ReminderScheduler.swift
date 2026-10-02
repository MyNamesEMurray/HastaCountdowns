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
        let reminderTime = ReminderPreferences.time
        var scheduled: [(date: Date, request: UNNotificationRequest)] = []

        for countdown in countdowns where !countdown.reminders.isEmpty {
            let target = countdown.nextOccurrence(after: now, calendar: calendar)
            for reminder in countdown.reminders {
                guard let fireDate = fireDate(for: reminder, target: target, isAllDay: countdown.isAllDay, reminderTime: reminderTime, calendar: calendar),
                      fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = countdown.displayTitle
                content.body = body(for: reminder, countdown: countdown, target: target)
                content.sound = .default
                content.userInfo = ["url": DeepLink.countdown(countdown.id).absoluteString]

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "\(identifierPrefix)\(countdown.id.uuidString)-\(reminder.rawValue)"
                scheduled.append((fireDate, UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)))
            }
        }

        return scheduled
            .sorted { $0.date < $1.date }
            .prefix(maximumPending)
            .map(\.request)
    }

    private static func fireDate(for reminder: Reminder, target: Date, isAllDay: Bool, reminderTime: DateComponents, calendar: Calendar) -> Date? {
        if isAllDay {
            let day = calendar.startOfDay(for: target)
            guard let reminderDay = calendar.date(byAdding: .day, value: -reminder.daysBefore, to: day) else { return nil }
            return calendar.date(bySettingHour: reminderTime.hour ?? 9, minute: reminderTime.minute ?? 0, second: 0, of: reminderDay)
        }
        return calendar.date(byAdding: .day, value: -reminder.daysBefore, to: target)
    }

    private static func body(for reminder: Reminder, countdown: Countdown, target: Date) -> String {
        switch reminder {
        case .dayOf:
            return countdown.isAllDay ? "Today's the day! 🎉" : "It's time! 🎉"
        case .dayBefore:
            return countdown.isAllDay ? "Tomorrow!" : "Tomorrow at \(target.formatted(date: .omitted, time: .shortened))."
        case .threeDaysBefore:
            return "3 days to go."
        case .weekBefore:
            return "One week to go."
        }
    }
}
