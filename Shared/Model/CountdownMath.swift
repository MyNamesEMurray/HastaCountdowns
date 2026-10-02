import Foundation

struct CountdownStatus: Equatable {
    enum Phase: Equatable {
        case upcoming
        case today
        case past
    }

    let target: Date
    let phase: Phase
    let days: Int
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
        switch phase {
        case .today: return "Today"
        case .upcoming: return days == 1 && remainder == nil ? "Tomorrow" : "in \(amount)"
        case .past: return days == 1 && remainder == nil ? "Yesterday" : "\(amount) ago"
        }
    }

    var compactPhrase: String {
        switch phase {
        case .today: return "Today"
        case .upcoming: return "\(number)\(unitLabel.prefix(1))"
        case .past: return "\(number)\(unitLabel.prefix(1)) ago"
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

        switch unit {
        case .weeks where days >= 7:
            let weeks = days / 7
            let extra = days % 7
            return CountdownStatus(
                target: target,
                phase: phase,
                days: days,
                number: "\(weeks)",
                unitLabel: Self.label(weeks, "week", "weeks"),
                remainder: extra > 0 ? Self.label(extra, "day", "days", includeNumber: true) : nil
            )
        case .months:
            let parts = calendar.dateComponents([.month, .day], from: from, to: to)
            let months = parts.month ?? 0
            let extra = parts.day ?? 0
            if months > 0 {
                return CountdownStatus(
                    target: target,
                    phase: phase,
                    days: days,
                    number: "\(months)",
                    unitLabel: Self.label(months, "month", "months"),
                    remainder: extra > 0 ? Self.label(extra, "day", "days", includeNumber: true) : nil
                )
            }
            fallthrough
        default:
            return CountdownStatus(
                target: target,
                phase: phase,
                days: days,
                number: days.formatted(),
                unitLabel: Self.label(days, "day", "days"),
                remainder: nil
            )
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
