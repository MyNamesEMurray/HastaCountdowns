import Foundation

struct CountdownStatus: Equatable {
    enum Phase: Equatable {
        case upcoming
        case today
        case past
    }

    enum Unit: Equatable {
        case years, months, weeks, days, hours, minutes

        var shortSymbol: String {
            switch self {
            case .years: "y"
            case .months: "mo"
            case .weeks: "w"
            case .days: "d"
            case .hours: "h"
            case .minutes: "m"
            }
        }
    }

    let target: Date
    let phase: Phase
    let days: Int
    let unit: Unit
    let number: String
    let unitLabel: String
    let remainder: String?

    var isPast: Bool { phase == .past }
    var isToday: Bool { phase == .today }

    var caption: String {
        switch phase {
        case .today: return "Today"
        case .upcoming: return remainder.map { "\(unitLabel) · \($0)" } ?? unitLabel
        case .past: return remainder.map { "\(unitLabel) · \($0) ago" } ?? "\(unitLabel) ago"
        }
    }

    var phrase: String {
        let amount = remainder.map { "\(number) \(unitLabel), \($0)" } ?? "\(number) \(unitLabel)"
        let isSingleDay = unit == .days && days == 1
        switch phase {
        case .today: return "Today"
        case .upcoming: return isSingleDay ? "Tomorrow" : "in \(amount)"
        case .past: return isSingleDay ? "Yesterday" : "\(amount) ago"
        }
    }

    var compactPhrase: String {
        switch phase {
        case .today: return "Today"
        case .upcoming: return "\(number)\(unit.shortSymbol)"
        case .past: return "\(number)\(unit.shortSymbol) ago"
        }
    }
}

extension Countdown {
    func nextOccurrence(after now: Date = .now, calendar: Calendar = .current) -> Date {
        guard let component = repeatRule.calendarComponent else { return date }
        let reference = isAllDay ? calendar.startOfDay(for: now) : now

        func isCurrent(_ candidate: Date) -> Bool {
            let comparable = isAllDay ? calendar.startOfDay(for: candidate) : candidate
            return comparable >= reference
        }

        if isCurrent(date) { return date }

        let elapsed = calendar.dateComponents([component], from: date, to: reference).value(for: component) ?? 0
        var step = max(0, elapsed - 1)
        var candidate = calendar.date(byAdding: component, value: step, to: date) ?? date
        while !isCurrent(candidate) && step < 100_000 {
            step += 1
            candidate = calendar.date(byAdding: component, value: step, to: date) ?? candidate
        }
        return candidate
    }

    func previousOccurrence(before target: Date, calendar: Calendar = .current) -> Date? {
        guard let component = repeatRule.calendarComponent else { return nil }
        return calendar.date(byAdding: component, value: -1, to: target)
    }

    func status(at now: Date = .now, calendar: Calendar = .current) -> CountdownStatus {
        let target = nextOccurrence(after: now, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: target)
        let signedDays = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
        let days = abs(signedDays)

        let phase: CountdownStatus.Phase
        if signedDays == 0 {
            phase = .today
        } else if signedDays > 0 {
            phase = .upcoming
        } else {
            phase = .past
        }

        let from = signedDays >= 0 ? startOfToday : startOfTarget
        let to = signedDays >= 0 ? startOfTarget : startOfToday

        func make(_ unit: CountdownStatus.Unit, _ value: Int, _ singular: String, _ plural: String, remainder: String? = nil) -> CountdownStatus {
            CountdownStatus(
                target: target,
                phase: phase,
                days: days,
                unit: unit,
                number: value.formatted(),
                unitLabel: Self.label(value, singular, plural),
                remainder: remainder
            )
        }

        func extra(_ value: Int, _ singular: String, _ plural: String) -> String? {
            value > 0 ? Self.label(value, singular, plural, includeNumber: true) : nil
        }

        switch resolvedUnit(days: days, target: target, now: now, from: from, to: to, calendar: calendar) {
        case .years:
            let parts = calendar.dateComponents([.year, .month], from: from, to: to)
            return make(.years, parts.year ?? 0, "year", "years", remainder: extra(parts.month ?? 0, "month", "months"))
        case .months:
            let parts = calendar.dateComponents([.month, .day], from: from, to: to)
            return make(.months, parts.month ?? 0, "month", "months", remainder: extra(parts.day ?? 0, "day", "days"))
        case .weeks:
            return make(.weeks, days / 7, "week", "weeks", remainder: extra(days % 7, "day", "days"))
        case .days:
            return make(.days, days, "day", "days")
        case .hours:
            let interval = abs(target.timeIntervalSince(now))
            let hours = Int(interval / 3_600)
            let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)
            return make(.hours, hours, "hour", "hours", remainder: extra(minutes, "minute", "minutes"))
        case .minutes:
            let interval = abs(target.timeIntervalSince(now))
            return make(.minutes, max(1, Int((interval / 60).rounded(.up))), "minute", "minutes")
        }
    }

    private func resolvedUnit(days: Int, target: Date, now: Date, from: Date, to: Date, calendar: Calendar) -> CountdownStatus.Unit {
        let parts = calendar.dateComponents([.year, .month], from: from, to: to)
        let years = parts.year ?? 0
        let totalMonths = years * 12 + (parts.month ?? 0)
        switch unit {
        case .days:
            return .days
        case .weeks:
            return days >= 7 ? .weeks : .days
        case .months:
            return totalMonths >= 1 ? .months : .days
        case .years:
            if years >= 1 { return .years }
            return totalMonths >= 1 ? .months : .days
        case .automatic:
            if !isAllDay && days <= 1 {
                let interval = abs(target.timeIntervalSince(now))
                if interval < 3_600 { return .minutes }
                if interval < 86_400 { return .hours }
            }
            if years >= 1 { return .years }
            if totalMonths >= 2 { return .months }
            if days >= 14 { return .weeks }
            return .days
        }
    }

    func progress(at now: Date = .now, calendar: Calendar = .current) -> Double {
        let target = nextOccurrence(after: now, calendar: calendar)
        let end = isAllDay ? calendar.startOfDay(for: target) : target
        let start: Date
        if let previous = previousOccurrence(before: target, calendar: calendar) {
            start = isAllDay ? calendar.startOfDay(for: previous) : previous
        } else {
            start = min(createdAt, end)
        }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return now >= end ? 1 : 0 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    func isLiveToday(at now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !isAllDay else { return false }
        let target = nextOccurrence(after: now, calendar: calendar)
        return calendar.isDate(target, inSameDayAs: now) && target > now
    }

    func formattedDate(at now: Date = .now, style: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        let target = nextOccurrence(after: now)
        if isAllDay {
            return target.formatted(date: style, time: .omitted)
        }
        return target.formatted(date: style, time: .shortened)
    }

    private static func label(_ value: Int, _ singular: String, _ plural: String, includeNumber: Bool = false) -> String {
        let word = value == 1 ? singular : plural
        return includeNumber ? "\(value) \(word)" : word
    }
}

extension Array where Element == Countdown {
    func upcoming(at now: Date = .now) -> [Countdown] {
        filter { !$0.status(at: now).isPast }
            .sorted { $0.nextOccurrence(after: now) < $1.nextOccurrence(after: now) }
    }

    func past(at now: Date = .now) -> [Countdown] {
        filter { $0.status(at: now).isPast }
            .sorted { $0.date > $1.date }
    }
}
