import ActivityKit
import Foundation

struct CountdownActivityAttributes: ActivityAttributes {
    // Only times travel in pushes. The widget looks up the name, symbol and color on the device.
    // Dates are seconds since 1970 so the push server can build the same JSON.
    struct ContentState: Codable, Hashable {
        var start: Date
        var target: Date
        var revision: Double

        init(start: Date, target: Date, revision: Double = 0) {
            self.start = start
            self.target = target
            self.revision = revision
        }

        private enum CodingKeys: String, CodingKey {
            case start, target, revision
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            start = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .start))
            target = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .target))
            revision = try container.decodeIfPresent(Double.self, forKey: .revision) ?? 0
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(start.timeIntervalSince1970, forKey: .start)
            try container.encode(target.timeIntervalSince1970, forKey: .target)
            try container.encode(revision, forKey: .revision)
        }

        var elapsedRange: ClosedRange<Date> { min(start, target)...target }
        var remainingRange: ClosedRange<Date> { min(.now, target)...target }
    }

    var countdownID: UUID
}
