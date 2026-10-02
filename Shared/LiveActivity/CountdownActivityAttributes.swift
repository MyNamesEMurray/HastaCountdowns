import ActivityKit
import Foundation

struct CountdownActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var countdown: Countdown
    }

    var countdownID: UUID
}
