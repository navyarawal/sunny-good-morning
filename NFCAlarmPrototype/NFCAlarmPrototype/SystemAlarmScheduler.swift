import Foundation

#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
#endif

/// Bridges Sunny to Apple's real system alarm surface when it is available.
///
/// iOS 26's AlarmKit is the only public API that can behave like Apple Clock:
/// it presents system alarm UI and can break through Silent mode and Focus.
/// Older iOS versions, denied AlarmKit authorization, or AlarmKit scheduling
/// failures fall back to the local-notification/audio chain in `AlarmManager`.
final class SystemAlarmScheduler {

    func requestAuthorizationIfPossible() async -> Bool {
        guard Self.isSystemAlarmKitEnabled else { return false }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return await SystemAlarmKitBackend.shared.requestAuthorizationIfPossible()
        }
        #endif
        return false
    }

    func schedule(_ alarm: AlarmItem, soundName: String) async -> Bool {
        guard Self.isSystemAlarmKitEnabled else { return false }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return await SystemAlarmKitBackend.shared.schedule(alarm, soundName: soundName)
        }
        #endif
        return false
    }

    func cancel(id: UUID) {
        guard Self.isSystemAlarmKitEnabled else { return }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            SystemAlarmKitBackend.shared.cancel(id: id)
        }
        #endif
    }

    func stop(id: UUID) {
        guard Self.isSystemAlarmKitEnabled else { return }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            SystemAlarmKitBackend.shared.stop(id: id)
        }
        #endif
    }

    func startObservingAlarmUpdates(onAlert: @escaping @MainActor (String) -> Void) {
        guard Self.isSystemAlarmKitEnabled else { return }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            SystemAlarmKitBackend.shared.startObservingAlarmUpdates(onAlert: onAlert)
        }
        #endif
    }

    // AlarmKit can break through Focus/Silent mode, but the system alarm UI has
    // a stop affordance that can't be forced through our NFC mission. Keep it
    // disabled while Sunny's product rule is "NFC or emergency challenge only."
    private static let isSystemAlarmKitEnabled = false
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct SunnyAlarmMetadata: AlarmMetadata {
    let alarmID: String
    let ringtoneName: String
}

@available(iOS 26.0, *)
private struct OpenSunnyAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Sunny"
    static var description = IntentDescription("Opens Sunny so you can tap your NFC sticker.")
    static var openAppWhenRun = true

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

@available(iOS 26.0, *)
private final class SystemAlarmKitBackend {
    static let shared = SystemAlarmKitBackend()

    private let manager = AlarmKit.AlarmManager.shared
    private var updatesTask: Task<Void, Never>?

    private init() {}

    func requestAuthorizationIfPossible() async -> Bool {
        switch manager.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await manager.requestAuthorization() == .authorized
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func schedule(_ alarm: AlarmItem, soundName: String) async -> Bool {
        guard await requestAuthorizationIfPossible() else { return false }

        do {
            try? manager.cancel(id: alarm.id)

            typealias Configuration = AlarmKit.AlarmManager.AlarmConfiguration<SunnyAlarmMetadata>

            let title = alarm.label.isEmpty ? "Find Sunny to stop the alarm" : "\(alarm.label): find Sunny"
            let findSunnyButton = AlarmButton(
                text: "Find Sunny",
                textColor: .white,
                systemImageName: "sun.max.fill"
            )
            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                secondaryButton: findSunnyButton,
                secondaryButtonBehavior: .custom
            )
            let presentation = AlarmPresentation(alert: alert)
            let metadata = SunnyAlarmMetadata(
                alarmID: alarm.id.uuidString,
                ringtoneName: alarm.ringtoneName
            )
            let attributes = AlarmAttributes(
                presentation: presentation,
                metadata: metadata,
                tintColor: Color(red: 0.91, green: 0.53, blue: 0.12)
            )
            let configuration = Configuration.alarm(
                schedule: schedule(for: alarm),
                attributes: attributes,
                stopIntent: OpenSunnyAlarmIntent(alarmID: alarm.id.uuidString),
                secondaryIntent: OpenSunnyAlarmIntent(alarmID: alarm.id.uuidString),
                sound: .named(soundName)
            )

            _ = try await manager.schedule(id: alarm.id, configuration: configuration)
            return true
        } catch {
            return false
        }
    }

    func cancel(id: UUID) {
        try? manager.cancel(id: id)
    }

    func stop(id: UUID) {
        try? manager.stop(id: id)
        try? manager.cancel(id: id)
    }

    func startObservingAlarmUpdates(onAlert: @escaping @MainActor (String) -> Void) {
        guard updatesTask == nil else { return }
        updatesTask = Task {
            for await alarms in manager.alarmUpdates {
                for alarm in alarms where alarm.state == .alerting {
                    await onAlert(alarm.id.uuidString)
                }
            }
        }
    }

    private func schedule(for alarm: AlarmItem) -> AlarmKit.Alarm.Schedule {
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.date)
        let hour = components.hour ?? 7
        let minute = components.minute ?? 0

        if alarm.repeatDays.isEmpty {
            return .fixed(nextOneTimeFireDate(for: alarm, hour: hour, minute: minute))
        }

        let time = AlarmKit.Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        return .relative(.init(
            time: time,
            repeats: .weekly(alarm.repeatDays.map(\.localeWeekday))
        ))
    }

    private func nextOneTimeFireDate(for alarm: AlarmItem, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let today = calendar.date(from: components) ?? alarm.date
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? alarm.date
    }
}

@available(iOS 26.0, *)
private extension RepeatDay {
    var localeWeekday: Locale.Weekday {
        switch self {
        case .sun: return .sunday
        case .mon: return .monday
        case .tue: return .tuesday
        case .wed: return .wednesday
        case .thu: return .thursday
        case .fri: return .friday
        case .sat: return .saturday
        }
    }
}
#endif
