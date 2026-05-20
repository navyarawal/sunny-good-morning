import ActivityKit
import Foundation

@available(iOS 16.2, *)
final class LiveActivityController {

    static let shared = LiveActivityController()
    private init() {}

    /// Idempotent — only starts a new Activity if none currently exists for this alarmID.
    func start(alarmID: String, label: String, ringtone: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if Activity<AlarmActivityAttributes>.activities.contains(where: { $0.attributes.alarmID == alarmID }) {
            return
        }

        let attributes = AlarmActivityAttributes(alarmID: alarmID, label: label)
        let state = AlarmActivityAttributes.ContentState(
            startedAt: .now,
            ringtoneName: ringtone
        )
        let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(60 * 60))

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities can fail to start (e.g. exceeded budget) — silent fallback
        }
    }

    func end(alarmID: String) {
        let activities = Activity<AlarmActivityAttributes>.activities.filter {
            $0.attributes.alarmID == alarmID
        }
        for activity in activities {
            let finalState = AlarmActivityAttributes.ContentState(
                startedAt: activity.content.state.startedAt,
                ringtoneName: activity.content.state.ringtoneName
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            Task {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
    }

    func endAll() {
        for activity in Activity<AlarmActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
