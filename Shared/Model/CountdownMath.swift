import Foundation

struct CountdownStatus: Equatable {
    enum Phase: Equatable {
        case upcoming
        case today
        case past
    }

    enum Unit: Equatable {
        case years, months, weeks, days, hours, minutes

        func label(_ value: Int) -> String {
            switch self {
            case .years: String(localized: "label.years \(value)")
            case .months: String(localized: "label.months \(value)")
            case .weeks: String(localized: "label.weeks \(value)")
            case .days: String(localized: "label.days \(value)")
            case .hours: String(localized: "label.hours \(value)")
            case .minutes: String(localized: "label.minutes \(value)")
            }
        }

        func amount(_ value: Int) -> String {
            switch self {
            case .years: String(localized: "amount.years \(value)")
            case .months: String(localized: "amount.months \(value)")
            case .weeks: String(localized: "amount.weeks \(value)")
            case .days: String(localized: "amount.days \(value)")
            case .hours: String(localized: "amount.hours \(value)")
            case .minutes: String(localized: "amount.minutes \(value)")
            }
        }

        func duration(_ value: Int) -> String {
            switch self {
            case .years: String(localized: "duration.years \(value)")
            case .months: String(localized: "duration.months \(value)")
            case .weeks: String(localized: "duration.weeks \(value)")
            case .days: String(localized: "duration.days \(value)")
            case .hours: String(localized: "duration.hours \(value)")
            case .minutes: String(localized: "duration.minutes \(value)")
            }
        }

        func short(_ value: Int) -> String {
            switch self {
            case .years: String(localized: "short.years \(value)")
            case .months: String(localized: "short.months \(value)")
            case .weeks: String(localized: "short.weeks \(value)")
            case .days: String(localized: "short.days \(value)")
            case .hours: String(localized: "short.hours \(value)")
            case .minutes: String(localized: "short.minutes \(value)")
            }
        }
    }

    let target: Date
    let phase: Phase
    let days: Int
    let unit: Unit
    let value: Int
    var remainderUnit: Unit?
    var remainderValue = 0

    var isPast: Bool { phase == .past }
    var isToday: Bool { phase == .today }

    var number: String { value.formatted() }

    var unitLabel: String { unit.label(value) }

    var remainder: String? { remainderUnit.map { $0.amount(remainderValue) } }

    var caption: String {
        switch phase {
        case .today:
            return String(localized: "Today")
        case .upcoming:
            return remainder.map { "\(unitLabel) · \($0)" } ?? unitLabel
        case .past:
            if let remainder {
                return String(localized: "caption.ago \(unitLabel) \(remainder)")
            }
            return String(localized: "caption.ago \(unitLabel)")
        }
    }

    var phrase: String {
        var duration = unit.duration(value)
        if let remainderUnit {
            duration = String(localized: "list.pair \(duration) \(remainderUnit.duration(remainderValue))")
        }
        let isSingleDay = unit == .days && days == 1
        switch phase {
        case .today: return String(localized: "Today")
        case .upcoming: return isSingleDay ? String(localized: "Tomorrow") : String(localized: "phrase.in \(duration)")
        case .past: return isSingleDay ? String(localized: "Yesterday") : String(localized: "phrase.ago \(duration)")
        }
    }

    var compactPhrase: String {
        switch phase {
        case .today: return String(localized: "Today")
        case .upcoming: return unit.short(value)
        case .past: return String(localized: "compact.ago \(unit.short(value))")
        }
    }
}

extension Countdown {
    func anchorDate(calendar: Calendar = .current) -> Date {
        guard isAllDay else { return date }
        var source = calendar
        source.timeZone = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? calendar.timeZone
        let day = source.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? date
    }

    mutating func adoptCurrentTimeZone(calendar: Calendar = .current) {
        date = anchorDate(calendar: calendar)
        timeZoneIdentifier = calendar.timeZone.identifier
    }

    func nextOccurrence(after now: Date = .now, calendar: Calendar = .current) -> Date {
        let anchor = anchorDate(calendar: calendar)
        guard let component = repeatRule.calendarComponent else { return anchor }
        let reference = isAllDay ? calendar.startOfDay(for: now) : now

        func isCurrent(_ candidate: Date) -> Bool {
            let comparable = isAllDay ? calendar.startOfDay(for: candidate) : candidate
            return comparable >= reference
        }

        if isCurrent(anchor) { return anchor }

        let elapsed = calendar.dateComponents([component], from: anchor, to: reference).value(for: component) ?? 0
        var step = max(0, elapsed - 1)
        var candidate = calendar.date(byAdding: component, value: step, to: anchor) ?? anchor
        while !isCurrent(candidate) && step < 100_000 {
            step += 1
            candidate = calendar.date(byAdding: component, value: step, to: anchor) ?? candidate
        }
        return candidate
    }

    func status(at now: Date = .now, calendar: Calendar = .current) -> CountdownStatus {
        let target = nextOccurrence(after: now, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: target)
        let signedDays = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
        let elapsedDays = abs(calendar.dateComponents([.day], from: min(now, target), to: max(now, target)).day ?? 0)
        let days: Int
        if isAllDay || signedDays == 0 {
            days = abs(signedDays)
        } else {
            days = max(1, elapsedDays)
        }

        let phase: CountdownStatus.Phase
        if signedDays == 0 {
            phase = .today
        } else if signedDays > 0 {
            phase = .upcoming
        } else {
            phase = .past
        }

        let from: Date
        let to: Date
        if isAllDay || signedDays == 0 {
            from = signedDays >= 0 ? startOfToday : startOfTarget
            to = signedDays >= 0 ? startOfTarget : startOfToday
        } else {
            from = min(now, target)
            to = max(now, target)
        }

        func make(_ unit: CountdownStatus.Unit, _ value: Int, remainder: CountdownStatus.Unit? = nil, _ remainderValue: Int = 0) -> CountdownStatus {
            CountdownStatus(
                target: target,
                phase: phase,
                days: days,
                unit: unit,
                value: value,
                remainderUnit: remainderValue > 0 ? remainder : nil,
                remainderValue: remainderValue > 0 ? remainderValue : 0
            )
        }

        switch resolvedUnit(days: days, target: target, now: now, from: from, to: to, calendar: calendar) {
        case .years:
            let parts = calendar.dateComponents([.year, .month], from: from, to: to)
            return make(.years, parts.year ?? 0, remainder: .months, parts.month ?? 0)
        case .months:
            let parts = calendar.dateComponents([.month, .day], from: from, to: to)
            return make(.months, parts.month ?? 0, remainder: .days, parts.day ?? 0)
        case .weeks:
            return make(.weeks, days / 7, remainder: .days, days % 7)
        case .days:
            return make(.days, days)
        case .hours:
            let interval = abs(target.timeIntervalSince(now))
            let hours = Int(interval / 3_600)
            let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)
            return make(.hours, hours, remainder: .minutes, minutes)
        case .minutes:
            let interval = abs(target.timeIntervalSince(now))
            return make(.minutes, max(1, Int((interval / 60).rounded(.up))))
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
}

struct CountdownSegment: Equatable {
    let value: Int
    let label: String
}

extension Countdown {
    func segments(at now: Date = .now, calendar: Calendar = .current) -> [CountdownSegment] {
        let target = nextOccurrence(after: now, calendar: calendar)
        let end = isAllDay ? calendar.startOfDay(for: target) : target
        let isPast = end < now
        if !isPast && !isAllDay && end.timeIntervalSince(now) < 86_400 { return [] }
        if isAllDay && calendar.isDate(target, inSameDayAs: now) { return [] }

        let from = isPast ? end : now
        let to = isPast ? now : end
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: from, to: to)
        let years = parts.year ?? 0
        let months = parts.month ?? 0
        let days = parts.day ?? 0
        let hours = parts.hour ?? 0

        func segment(_ unit: CountdownStatus.Unit, _ value: Int) -> CountdownSegment {
            CountdownSegment(value: value, label: unit.label(value))
        }

        if years > 0 {
            return [segment(.years, years), segment(.months, months), segment(.days, days)]
        }
        if months > 0 {
            return [segment(.months, months), segment(.days, days), segment(.hours, hours)]
        }
        return [segment(.days, days), segment(.hours, hours)]
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
