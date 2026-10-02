import Foundation

struct Countdown: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Countdown.defaultDate
    var isAllDay: Bool = true
    var repeatRule: RepeatRule = .never
    var symbol: String = "star.fill"
    var color: CountdownColor = .blue
    var customColorHex: String?
    var unit: DisplayUnit = .days
    var style: WidgetStyle = .classic
    var typeface: Typeface = .rounded
    var backgroundImageID: String?
    var reminders: Set<Reminder> = [.dayOf]
    var createdAt: Date = .now

    static var defaultDate: Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: 7, to: start) ?? start
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        date: Date = Countdown.defaultDate,
        isAllDay: Bool = true,
        repeatRule: RepeatRule = .never,
        symbol: String = "star.fill",
        color: CountdownColor = .blue,
        customColorHex: String? = nil,
        unit: DisplayUnit = .days,
        style: WidgetStyle = .classic,
        typeface: Typeface = .rounded,
        backgroundImageID: String? = nil,
        reminders: Set<Reminder> = [.dayOf],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.repeatRule = repeatRule
        self.symbol = symbol
        self.color = color
        self.customColorHex = customColorHex
        self.unit = unit
        self.style = style
        self.typeface = typeface
        self.backgroundImageID = backgroundImageID
        self.reminders = reminders
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try container.decode(Date.self, forKey: .date)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? true
        repeatRule = (try? container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule)) ?? .never
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? "star.fill"
        color = (try? container.decodeIfPresent(CountdownColor.self, forKey: .color)) ?? .blue
        customColorHex = try container.decodeIfPresent(String.self, forKey: .customColorHex)
        unit = (try? container.decodeIfPresent(DisplayUnit.self, forKey: .unit)) ?? .days
        style = (try? container.decodeIfPresent(WidgetStyle.self, forKey: .style)) ?? .classic
        typeface = (try? container.decodeIfPresent(Typeface.self, forKey: .typeface)) ?? .rounded
        backgroundImageID = try container.decodeIfPresent(String.self, forKey: .backgroundImageID)
        reminders = (try? container.decodeIfPresent(Set<Reminder>.self, forKey: .reminders)) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
    }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case never, weekly, monthly, yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Never"
        case .weekly: "Every Week"
        case .monthly: "Every Month"
        case .yearly: "Every Year"
        }
    }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .never: nil
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }
}

enum DisplayUnit: String, Codable, CaseIterable, Identifiable {
    case days, weeks, months

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days: "Days"
        case .weeks: "Weeks"
        case .months: "Months"
        }
    }
}

enum Reminder: String, Codable, CaseIterable, Identifiable, Comparable {
    case dayOf, dayBefore, threeDaysBefore, weekBefore

    var id: String { rawValue }

    var daysBefore: Int {
        switch self {
        case .dayOf: 0
        case .dayBefore: 1
        case .threeDaysBefore: 3
        case .weekBefore: 7
        }
    }

    func title(isAllDay: Bool) -> String {
        switch self {
        case .dayOf: isAllDay ? "On the Day" : "At Time of Event"
        case .dayBefore: "1 Day Before"
        case .threeDaysBefore: "3 Days Before"
        case .weekBefore: "1 Week Before"
        }
    }

    static func < (lhs: Reminder, rhs: Reminder) -> Bool {
        lhs.daysBefore < rhs.daysBefore
    }
}

enum CountdownColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, graphite

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum WidgetStyle: String, Codable, CaseIterable, Identifiable {
    case classic, minimal, vivid, night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .minimal: "Minimal"
        case .vivid: "Vivid"
        case .night: "Night"
        }
    }

    var isPremium: Bool {
        switch self {
        case .classic, .minimal: false
        case .vivid, .night: true
        }
    }
}

enum Typeface: String, Codable, CaseIterable, Identifiable {
    case rounded, standard, serif, mono, condensed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rounded: "Rounded"
        case .standard: "Standard"
        case .serif: "Serif"
        case .mono: "Mono"
        case .condensed: "Condensed"
        }
    }

    var isPremium: Bool {
        switch self {
        case .rounded, .standard: false
        case .serif, .mono, .condensed: true
        }
    }
}

extension Countdown {
    var usesPremiumFeatures: Bool {
        style.isPremium || typeface.isPremium || customColorHex != nil || backgroundImageID != nil
    }

    func resolved(isPremium: Bool) -> Countdown {
        guard !isPremium else { return self }
        var copy = self
        if copy.style.isPremium { copy.style = .classic }
        if copy.typeface.isPremium { copy.typeface = .rounded }
        copy.customColorHex = nil
        copy.backgroundImageID = nil
        return copy
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}

extension Countdown {
    static let samples: [Countdown] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func days(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: today) ?? today }
        return [
            Countdown(title: "Tokyo Trip", date: days(42), symbol: "airplane", color: .blue, createdAt: days(-30)),
            Countdown(title: "Maya's Birthday", date: days(9), repeatRule: .yearly, symbol: "birthday.cake.fill", color: .pink, createdAt: days(-200)),
            Countdown(title: "Concert", date: days(17), symbol: "music.mic", color: .purple, style: .vivid, createdAt: days(-12)),
            Countdown(title: "Marathon", date: days(88), symbol: "figure.run", color: .orange, unit: .weeks, createdAt: days(-60)),
        ]
    }()
}
