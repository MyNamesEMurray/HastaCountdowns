import ActivityKit
import Foundation

struct CountdownActivityAttributes: ActivityAttributes {
    // Dates travel as seconds since 1970 so the push server can build the same JSON.
    struct ContentState: Codable, Hashable {
        var title: String
        var symbol: String
        var tintHex: String
        var start: Date
        var target: Date

        init(title: String, symbol: String, tintHex: String, start: Date, target: Date) {
            self.title = title
            self.symbol = symbol
            self.tintHex = tintHex
            self.start = start
            self.target = target
        }

        private enum CodingKeys: String, CodingKey {
            case title, symbol, tintHex, start, target
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            symbol = try container.decode(String.self, forKey: .symbol)
            tintHex = try container.decode(String.self, forKey: .tintHex)
            start = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .start))
            target = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .target))
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try container.encode(symbol, forKey: .symbol)
            try container.encode(tintHex, forKey: .tintHex)
            try container.encode(start.timeIntervalSince1970, forKey: .start)
            try container.encode(target.timeIntervalSince1970, forKey: .target)
        }

        var elapsedRange: ClosedRange<Date> { min(start, target)...target }
        var remainingRange: ClosedRange<Date> { min(.now, target)...target }
    }

    var countdownID: UUID
}
