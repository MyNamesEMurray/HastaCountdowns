import Foundation

struct ReminderRule: Codable, Hashable, Identifiable {
    enum Unit: String, Codable, CaseIterable, Identifiable {
        case minutes, hours, days, weeks, months

        var id: String { rawValue }

        var usesTimeOfDay: Bool {
            switch self {
            case .minutes, .hours: false
            case .days, .weeks, .months: true
            }
        }

        var approximateSeconds: TimeInterval {
            switch self {
            case .minutes: 60
            case .hours: 3_600
            case .days: 86_400
            case .weeks: 604_800
            case .months: 2_592_000
            }
        }

        func name(for amount: Int) -> String {
            let singular: String
            switch self {
            case .minutes: singular = "minute"
            case .hours: singular = "hour"
            case .days: singular = "day"
            case .weeks: singular = "week"
            case .months: singular = "month"
            }
            return amount == 1 ? singular : singular + "s"
        }

        static func available(isAllDay: Bool) -> [Unit] {
            isAllDay ? [.days, .weeks, .months] : allCases
        }
    }

    var id: UUID = UUID()
    var amount: Int = 0
    var unit: Unit = .days
    var hour: Int?
    var minute: Int?

    init(id: UUID = UUID(), amount: Int = 0, unit: Unit = .days, hour: Int? = nil, minute: Int? = nil) {
        self.id = id
        self.amount = max(0, amount)
        self.unit = unit
        self.hour = hour
        self.minute = minute
    }

    var hasCustomTime: Bool {
        unit.usesTimeOfDay && hour != nil
    }

    var leadTime: TimeInterval {
        Double(amount) * unit.approximateSeconds
    }

    func matches(_ other: ReminderRule) -> Bool {
        amount == other.amount && unit == other.unit && hour == other.hour && minute == other.minute
    }

    func fireDate(for target: Date, isAllDay: Bool, defaultTime: DateComponents, calendar: Calendar = .current) -> Date? {
        let defaultHour = defaultTime.hour ?? 9
        let defaultMinute = defaultTime.minute ?? 0
        switch unit {
        case .minutes, .hours:
            let base = isAllDay
                ? calendar.date(bySettingHour: defaultHour, minute: defaultMinute, second: 0, of: calendar.startOfDay(for: target)) ?? target
                : target
            return base.addingTimeInterval(-leadTime)
        case .days, .weeks, .months:
            let component: Calendar.Component = unit == .days ? .day : unit == .weeks ? .weekOfYear : .month
            let base = isAllDay ? calendar.startOfDay(for: target) : target
            guard let shifted = calendar.date(byAdding: component, value: -amount, to: base) else { return nil }
            if let hour {
                return calendar.date(bySettingHour: hour, minute: minute ?? 0, second: 0, of: shifted)
            }
            if isAllDay {
                return calendar.date(bySettingHour: defaultHour, minute: defaultMinute, second: 0, of: shifted)
            }
            return shifted
        }
    }

    func title(isAllDay: Bool, defaultTime: DateComponents, calendar: Calendar = .current) -> String {
        let offset: String
        if amount == 0 {
            offset = isAllDay || hasCustomTime ? "On the day" : "At time of event"
        } else {
            offset = "\(amount) \(unit.name(for: amount)) before"
        }
        guard unit.usesTimeOfDay else { return offset }
        if let hour {
            return "\(offset) at \(Self.timeText(hour: hour, minute: minute ?? 0, calendar: calendar))"
        }
        if isAllDay {
            return "\(offset) at \(Self.timeText(hour: defaultTime.hour ?? 9, minute: defaultTime.minute ?? 0, calendar: calendar))"
        }
        return offset
    }

    var notificationBody: String {
        if amount == 0 {
            return unit.usesTimeOfDay ? "Today's the day! 🎉" : "It's time! 🎉"
        }
        if amount == 1 && unit == .days {
            return "Tomorrow!"
        }
        return "\(amount) \(unit.name(for: amount)) to go."
    }

    static func timeText(hour: Int, minute: Int, calendar: Calendar = .current) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = calendar.date(from: components) ?? .now
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, calendar: calendar, timeZone: calendar.timeZone))
    }

    static let onTheDay = ReminderRule()

    static func presets(isAllDay: Bool) -> [ReminderRule] {
        if isAllDay {
            return [
                ReminderRule(amount: 0, unit: .days),
                ReminderRule(amount: 1, unit: .days),
                ReminderRule(amount: 2, unit: .days),
                ReminderRule(amount: 3, unit: .days),
                ReminderRule(amount: 1, unit: .weeks),
                ReminderRule(amount: 2, unit: .weeks),
                ReminderRule(amount: 1, unit: .months),
            ]
        }
        return [
            ReminderRule(amount: 0, unit: .minutes),
            ReminderRule(amount: 15, unit: .minutes),
            ReminderRule(amount: 30, unit: .minutes),
            ReminderRule(amount: 1, unit: .hours),
            ReminderRule(amount: 2, unit: .hours),
            ReminderRule(amount: 1, unit: .days),
            ReminderRule(amount: 2, unit: .days),
            ReminderRule(amount: 1, unit: .weeks),
        ]
    }
}

enum LegacyReminder: String, Codable {
    case dayOf, dayBefore, threeDaysBefore, weekBefore

    var rule: ReminderRule {
        switch self {
        case .dayOf: ReminderRule(amount: 0, unit: .days)
        case .dayBefore: ReminderRule(amount: 1, unit: .days)
        case .threeDaysBefore: ReminderRule(amount: 3, unit: .days)
        case .weekBefore: ReminderRule(amount: 1, unit: .weeks)
        }
    }
}

extension Array where Element == ReminderRule {
    var sortedByLeadTime: [ReminderRule] {
        sorted { lhs, rhs in
            if lhs.leadTime != rhs.leadTime { return lhs.leadTime < rhs.leadTime }
            return (lhs.hour ?? -1, lhs.minute ?? -1) < (rhs.hour ?? -1, rhs.minute ?? -1)
        }
    }
}
