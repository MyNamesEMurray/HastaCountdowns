import Foundation

struct Countdown: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Countdown.defaultDate
    var isAllDay: Bool = true
    var timeZoneIdentifier: String?
    var repeatRule: RepeatRule = .never
    var symbol: String = "star.fill"
    var color: CountdownColor = .blue
    var customColorHex: String?
    var unit: DisplayUnit = .automatic
    var style: WidgetStyle = .classic
    var typeface: Typeface = .rounded
    var backgroundImageID: String?
    var backgroundFraming: BackgroundFraming?
    var reminders: [ReminderRule] = [.onTheDay]
    var createdAt: Date = .now
    var modifiedAt: Date = .now

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
        timeZoneIdentifier: String? = nil,
        repeatRule: RepeatRule = .never,
        symbol: String = "star.fill",
        color: CountdownColor = .blue,
        customColorHex: String? = nil,
        unit: DisplayUnit = .automatic,
        style: WidgetStyle = .classic,
        typeface: Typeface = .rounded,
        backgroundImageID: String? = nil,
        backgroundFraming: BackgroundFraming? = nil,
        reminders: [ReminderRule] = [.onTheDay],
        createdAt: Date = .now,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.timeZoneIdentifier = timeZoneIdentifier
        self.repeatRule = repeatRule
        self.symbol = symbol
        self.color = color
        self.customColorHex = customColorHex
        self.unit = unit
        self.style = style
        self.typeface = typeface
        self.backgroundImageID = backgroundImageID
        self.backgroundFraming = backgroundFraming
        self.reminders = reminders
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try container.decode(Date.self, forKey: .date)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? true
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
        repeatRule = (try? container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule)) ?? .never
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? "star.fill"
        color = (try? container.decodeIfPresent(CountdownColor.self, forKey: .color)) ?? .blue
        customColorHex = try container.decodeIfPresent(String.self, forKey: .customColorHex)
        unit = (try? container.decodeIfPresent(DisplayUnit.self, forKey: .unit)) ?? .days
        style = (try? container.decodeIfPresent(WidgetStyle.self, forKey: .style)) ?? .classic
        typeface = (try? container.decodeIfPresent(Typeface.self, forKey: .typeface)) ?? .rounded
        backgroundImageID = try container.decodeIfPresent(String.self, forKey: .backgroundImageID)
        backgroundFraming = try? container.decodeIfPresent(BackgroundFraming.self, forKey: .backgroundFraming)
        if let rules = try? container.decodeIfPresent([ReminderRule].self, forKey: .reminders) {
            reminders = rules
        } else if let legacy = try? container.decodeIfPresent([LegacyReminder].self, forKey: .reminders) {
            reminders = legacy.map(\.rule).sortedByLeadTime
        } else {
            reminders = []
        }
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
    }
}

struct RepeatRule: Hashable {
    enum Frequency: String, Codable, CaseIterable, Identifiable {
        case daily, weekly, monthly, yearly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .daily: String(localized: "Daily")
            case .weekly: String(localized: "Weekly")
            case .monthly: String(localized: "Monthly")
            case .yearly: String(localized: "Yearly")
            }
        }

        var component: Calendar.Component {
            switch self {
            case .daily: .day
            case .weekly: .weekOfYear
            case .monthly: .month
            case .yearly: .year
            }
        }

        var unit: CountdownStatus.Unit {
            switch self {
            case .daily: .days
            case .weekly: .weeks
            case .monthly: .months
            case .yearly: .years
            }
        }
    }

    struct OrdinalWeekday: Codable, Hashable {
        var ordinal: Int
        var weekday: Int

        static let ordinals = [1, 2, 3, 4, 5, -1]

        static func title(for ordinal: Int) -> String {
            switch ordinal {
            case 1: String(localized: "ordinal.first")
            case 2: String(localized: "ordinal.second")
            case 3: String(localized: "ordinal.third")
            case 4: String(localized: "ordinal.fourth")
            case 5: String(localized: "ordinal.fifth")
            default: String(localized: "ordinal.last")
            }
        }
    }

    var frequency: Frequency?
    var interval: Int = 1
    var weekdays: Set<Int> = []
    var ordinalWeekday: OrdinalWeekday?

    static let never = RepeatRule()
    static let daily = RepeatRule(frequency: .daily)
    static let weekly = RepeatRule(frequency: .weekly)
    static let monthly = RepeatRule(frequency: .monthly)
    static let yearly = RepeatRule(frequency: .yearly)
    static let presets: [RepeatRule] = [.never, .daily, .weekly, RepeatRule(frequency: .weekly, interval: 2), .monthly, .yearly]

    var isCustom: Bool { !Self.presets.contains(self) }

    var title: String {
        guard let frequency else { return String(localized: "Never") }
        let base: String
        if interval > 1 {
            base = String(localized: "repeat.every \(frequency.unit.duration(interval))")
        } else {
            switch frequency {
            case .daily: base = String(localized: "Every Day")
            case .weekly: base = String(localized: "Every Week")
            case .monthly: base = String(localized: "Every Month")
            case .yearly: base = String(localized: "Every Year")
            }
        }
        let symbols = Calendar.current.weekdaySymbols
        if frequency == .weekly, !weekdays.isEmpty {
            let names = Self.orderedWeekdays().filter { weekdays.contains($0) }.map { symbols[$0 - 1] }
            return String(localized: "repeat.on \(base) \(names.formatted(.list(type: .and)))")
        }
        if frequency == .monthly, let ordinalWeekday {
            return String(localized: "repeat.onThe \(base) \(OrdinalWeekday.title(for: ordinalWeekday.ordinal)) \(symbols[ordinalWeekday.weekday - 1])")
        }
        return base
    }

    var sentence: String {
        let title = self.title
        let phrase = title.prefix(1).lowercased() + String(title.dropFirst())
        return String(localized: "repeat.sentence \(phrase)")
    }

    static func orderedWeekdays(calendar: Calendar = .current) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    func occurrences(inPeriodStartingAt start: Date, calendar: Calendar) -> [Date] {
        let time = calendar.dateComponents([.hour, .minute, .second], from: start)
        func atTime(_ day: Date) -> Date? {
            calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day)
        }
        switch frequency {
        case .weekly where !weekdays.isEmpty:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: start) else { return [start] }
            return (0..<7)
                .compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
                .filter { weekdays.contains(calendar.component(.weekday, from: $0)) }
                .compactMap(atTime)
        case .monthly:
            guard let ordinalWeekday else { return [start] }
            guard let month = calendar.dateInterval(of: .month, for: start) else { return [] }
            let matches = (0..<31)
                .compactMap { calendar.date(byAdding: .day, value: $0, to: month.start) }
                .filter { $0 < month.end && calendar.component(.weekday, from: $0) == ordinalWeekday.weekday }
            let index = ordinalWeekday.ordinal < 0 ? matches.count + ordinalWeekday.ordinal : ordinalWeekday.ordinal - 1
            guard matches.indices.contains(index), let date = atTime(matches[index]) else { return [] }
            return [date]
        default:
            return [start]
        }
    }
}

extension RepeatRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case frequency, interval, weekdays, ordinalWeekday
    }

    init(from decoder: Decoder) throws {
        if let legacy = try? decoder.singleValueContainer().decode(String.self) {
            self.init(frequency: Frequency(rawValue: legacy))
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            frequency: try container.decodeIfPresent(Frequency.self, forKey: .frequency),
            interval: max(1, try container.decodeIfPresent(Int.self, forKey: .interval) ?? 1),
            weekdays: (try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? []).filter { (1...7).contains($0) },
            ordinalWeekday: try container.decodeIfPresent(OrdinalWeekday.self, forKey: .ordinalWeekday).flatMap { (1...7).contains($0.weekday) ? $0 : nil }
        )
    }

    func encode(to encoder: Encoder) throws {
        if interval == 1, weekdays.isEmpty, ordinalWeekday == nil {
            var container = encoder.singleValueContainer()
            try container.encode(frequency?.rawValue ?? "never")
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(frequency, forKey: .frequency)
        try container.encode(interval, forKey: .interval)
        try container.encode(weekdays.sorted(), forKey: .weekdays)
        try container.encodeIfPresent(ordinalWeekday, forKey: .ordinalWeekday)
    }
}

enum DisplayUnit: String, Codable, CaseIterable, Identifiable {
    case automatic, days, weeks, months, years

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: String(localized: "Auto")
        case .days: String(localized: "Days")
        case .weeks: String(localized: "Weeks")
        case .months: String(localized: "Months")
        case .years: String(localized: "Years")
        }
    }

    var detail: String {
        switch self {
        case .automatic: String(localized: "Picks years, months, weeks, days, hours, or minutes depending on how far away it is.")
        case .days: String(localized: "Always counts in days.")
        case .weeks: String(localized: "Weeks and days, once it's at least a week away.")
        case .months: String(localized: "Months and days, once it's at least a month away.")
        case .years: String(localized: "Years and months, once it's at least a year away.")
        }
    }
}

enum CountdownColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .mint: String(localized: "Mint")
        case .teal: String(localized: "Teal")
        case .cyan: String(localized: "Cyan")
        case .blue: String(localized: "Blue")
        case .indigo: String(localized: "Indigo")
        case .purple: String(localized: "Purple")
        case .pink: String(localized: "Pink")
        case .brown: String(localized: "Brown")
        case .graphite: String(localized: "Graphite")
        }
    }
}

enum WidgetStyle: String, Codable, CaseIterable, Identifiable {
    case classic, minimal, vivid, night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .minimal: String(localized: "Minimal")
        case .vivid: String(localized: "Vivid")
        case .night: String(localized: "Night")
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
        case .rounded: String(localized: "Rounded")
        case .standard: String(localized: "Standard")
        case .serif: String(localized: "Serif")
        case .mono: String(localized: "Mono")
        case .condensed: String(localized: "Condensed")
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
        copy.backgroundFraming = nil
        return copy
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Untitled") : trimmed
    }
}

extension Countdown {
    static let samples: [Countdown] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func days(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: today) ?? today }
        func id(_ suffix: String) -> UUID { UUID(uuidString: "00000000-0000-0000-0000-0000000000\(suffix)")! }
        return [
            Countdown(id: id("01"), title: String(localized: "Tokyo Trip"), date: days(42), symbol: "airplane", color: .blue, createdAt: days(-30)),
            Countdown(id: id("02"), title: String(localized: "Maya's Birthday"), date: days(9), repeatRule: .yearly, symbol: "birthday.cake.fill", color: .pink, createdAt: days(-200)),
            Countdown(id: id("03"), title: String(localized: "Concert"), date: days(17), symbol: "music.mic", color: .purple, style: .vivid, createdAt: days(-12)),
            Countdown(id: id("04"), title: String(localized: "Marathon"), date: days(88), symbol: "figure.run", color: .orange, unit: .weeks, createdAt: days(-60)),
            Countdown(id: id("05"), title: String(localized: "Dinner Reservation at Lucia's Trattoria"), date: Date.now.addingTimeInterval(5 * 3_600 + 20 * 60), isAllDay: false, symbol: "fork.knife", color: .green, createdAt: days(-3)),
        ]
    }()
}
