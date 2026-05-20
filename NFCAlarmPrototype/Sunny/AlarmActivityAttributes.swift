import ActivityKit
import Foundation

// Shared between the main app and the AlarmWidget extension target.
// MUST be added to BOTH targets via File Inspector → Target Membership.
struct AlarmActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startedAt: Date
        var ringtoneName: String
    }

    var alarmID: String
    var label: String
}
