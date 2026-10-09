import Foundation

extension Countdown {
    init?(ics: String, calendar: Calendar = .current) {
        let lines = ics
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let start = lines.firstIndex(where: { $0.uppercased() == "BEGIN:VEVENT" }) else { return nil }

        var fields: [String: (params: [String: String], value: String)] = [:]
        var depth = 0
        for line in lines[(start + 1)...] {
            let upper = line.uppercased()
            if upper == "END:VEVENT" && depth == 0 { break }
            if upper.hasPrefix("BEGIN:") { depth += 1; continue }
            if upper.hasPrefix("END:") { depth -= 1; continue }
            guard depth == 0, let colon = line.firstIndex(of: ":") else { continue }
            var parts = line[..<colon].split(separator: ";").map(String.init)
            guard !parts.isEmpty else { continue }
            let name = parts.removeFirst().uppercased()
            guard fields[name] == nil else { continue }
            let params = Dictionary(parts.compactMap { part -> (String, String)? in
                let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
                return pair.count == 2 ? (pair[0].uppercased(), pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))) : nil
            }, uniquingKeysWith: { first, _ in first })
            fields[name] = (params, String(line[line.index(after: colon)...]))
        }

        guard let dtstart = fields["DTSTART"] else { return nil }
        let digits = dtstart.value.compactMap { $0.isASCII ? $0.wholeNumberValue : nil }
        guard digits.count >= 8 else { return nil }
        func number(_ range: Range<Int>) -> Int { digits[range].reduce(0) { $0 * 10 + $1 } }
        let isAllDay = dtstart.params["VALUE"]?.uppercased() == "DATE" || digits.count < 14

        var source = Calendar(identifier: .gregorian)
        if isAllDay {
            source.timeZone = calendar.timeZone
        } else if dtstart.value.uppercased().hasSuffix("Z") {
            source.timeZone = TimeZone(identifier: "UTC")!
        } else {
            source.timeZone = dtstart.params["TZID"].flatMap(TimeZone.init(identifier:)) ?? calendar.timeZone
        }
        var components = DateComponents(year: number(0..<4), month: number(4..<6), day: number(6..<8))
        if !isAllDay {
            components.hour = number(8..<10)
            components.minute = number(10..<12)
            components.second = number(12..<14)
        }
        guard let date = source.date(from: components) else { return nil }

        var repeatRule = RepeatRule.never
        if let rrule = fields["RRULE"]?.value {
            let parts = Dictionary(rrule.uppercased().split(separator: ";").compactMap { part -> (String, String)? in
                let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
                return pair.count == 2 ? (pair[0], pair[1]) : nil
            }, uniquingKeysWith: { first, _ in first })
            if (parts["INTERVAL"] ?? "1") == "1" {
                switch parts["FREQ"] {
                case "WEEKLY": repeatRule = .weekly
                case "MONTHLY": repeatRule = .monthly
                case "YEARLY": repeatRule = .yearly
                default: break
                }
            }
        }

        let title = (fields["SUMMARY"]?.value ?? "")
            .replacingOccurrences(of: "\\n", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        self.init(
            title: title,
            date: date,
            isAllDay: isAllDay,
            timeZoneIdentifier: isAllDay ? calendar.timeZone.identifier : source.timeZone.identifier,
            repeatRule: repeatRule
        )
    }
}
