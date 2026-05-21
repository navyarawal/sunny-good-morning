import BackgroundTasks
import Foundation
import UserNotifications

/// Opportunistic wake-up layer for the app-alive path.
///
/// BGAppRefresh is not an alarm API and Apple does not guarantee exact
/// delivery. We use it only to improve odds that Sunny wakes shortly before an
/// alarm, restarts its background audio keep-alive, and refreshes fallback
/// notifications. AlarmKit and local notification chains remain the hard
/// fallbacks.
final class AlarmBackgroundTaskCoordinator {
    static let shared = AlarmBackgroundTaskCoordinator()

    static let refreshIdentifier = "UCLA.NFCAlarmPrototype.alarm-refresh"

    private var didRegister = false

    private init() {}

    func register() {
        guard !didRegister else { return }
        didRegister = true

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleRefresh(task)
        }
    }

    func scheduleNextRefresh(for alarms: [AlarmItem]) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)

        let enabled = alarms.filter(\.isEnabled)
        guard let next = enabled.compactMap(nextFiringDate(for:)).min() else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        let target = next.addingTimeInterval(-15 * 60)
        request.earliestBeginDate = maxDate(Date().addingTimeInterval(60), target)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // BGTaskScheduler is opportunistic and may reject requests under
            // Low Power Mode, simulator, denied Background App Refresh, or
            // temporary system pressure. AlarmKit/local notifications still run.
        }
    }

    private func handleRefresh(_ task: BGAppRefreshTask) {
        let alarms = loadPersistedAlarms()
        scheduleNextRefresh(for: alarms)

        var completed = false
        func complete(_ success: Bool) {
            guard !completed else { return }
            completed = true
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = { [weak self] in
            if let alarm = self?.nextAlarm(from: alarms) {
                self?.scheduleLastResortNotification(
                    for: alarm,
                    reason: "Sunny was given too little background time. Tap to open and scan your sticker."
                )
            }
            complete(false)
        }

        NotificationCenter.default.post(name: .alarmBackgroundRefresh, object: nil)

        if let due = alarms.first(where: { alarm in
            guard let fire = nextFiringDate(for: alarm) else { return false }
            return fire.timeIntervalSinceNow <= 90
        }) {
            NotificationCenter.default.post(
                name: .alarmDidFire,
                object: nil,
                userInfo: ["alarmID": due.id.uuidString, "source": "BGAppRefresh"]
            )
        }

        complete(true)
    }

    private func loadPersistedAlarms() -> [AlarmItem] {
        guard let data = UserDefaults.standard.data(forKey: "alarms"),
              let saved = try? JSONDecoder().decode([AlarmItem].self, from: data) else {
            return []
        }
        return saved
    }

    private func nextAlarm(from alarms: [AlarmItem]) -> AlarmItem? {
        alarms
            .filter(\.isEnabled)
            .compactMap { alarm -> (AlarmItem, Date)? in
                guard let fire = nextFiringDate(for: alarm) else { return nil }
                return (alarm, fire)
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func scheduleLastResortNotification(for alarm: AlarmItem, reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sunny alarm needs attention"
        content.body = reason
        content.categoryIdentifier = "ALARM"
        content.userInfo = [
            "alarmID": alarm.id.uuidString,
            "chainIndex": 0,
            "ringtone": alarm.ringtoneName,
            "volume": alarm.volume
        ]
        content.interruptionLevel = .timeSensitive
        content.sound = UNNotificationSound(
            named: UNNotificationSoundName(rawValue: "rise_\(alarm.ringtoneName.lowercased()).wav")
        )

        let request = UNNotificationRequest(
            identifier: "alarm-\(alarm.id.uuidString)-bg-expired-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func nextFiringDate(for alarm: AlarmItem) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let time = calendar.dateComponents([.hour, .minute], from: alarm.date)

        if alarm.repeatDays.isEmpty {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0
            if let date = calendar.date(from: components), date > now { return date }
            return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components) ?? now)
        }

        for offset in 0..<8 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            guard let repeatDay = RepeatDay.allCases.first(where: { $0.weekdayIndex == weekday }),
                  alarm.repeatDays.contains(repeatDay) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: candidate)
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0
            if let date = calendar.date(from: components), date > now { return date }
        }

        return nil
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }
}

extension Notification.Name {
    static let alarmBackgroundRefresh = Notification.Name("alarmBackgroundRefresh")
}
