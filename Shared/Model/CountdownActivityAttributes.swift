import ActivityKit
import Foundation

struct CountdownActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var symbol: String
        var tintHex: String
        var start: Date
        var target: Date

        var elapsedRange: ClosedRange<Date> { min(start, target)...target }
        var remainingRange: ClosedRange<Date> { min(.now, target)...target }
    }

    var countdownID: UUID
}
