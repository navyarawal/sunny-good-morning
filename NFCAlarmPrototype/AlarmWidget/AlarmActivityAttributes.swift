import ActivityKit
import Foundation

struct AlarmActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startedAt: Date
        var ringtoneName: String
    }

    var alarmID: String
    var label: String
}
