import Foundation
import Combine

// MARK: - Sun Growth Levels

enum SunLevel: Int, CaseIterable {
    case seedling  = 0
    case rising    = 1
    case shining   = 2
    case glowing   = 3
    case radiant   = 4
    case blazing   = 5
    case legendary = 6

    static func forStreak(_ days: Int) -> SunLevel {
        switch days {
        case 0..<3:   return .seedling
        case 3..<7:   return .rising
        case 7..<14:  return .shining
        case 14..<21: return .glowing
        case 21..<30: return .radiant
        case 30..<50: return .blazing
        default:      return .legendary
        }
    }

    var title: String {
        switch self {
        case .seedling:  return "Seedling"
        case .rising:    return "Rising Sun"
        case .shining:   return "Shining"
        case .glowing:   return "Glowing"
        case .radiant:   return "Radiant"
        case .blazing:   return "Blazing"
        case .legendary: return "Legendary"
        }
    }

    var subtitle: String {
        switch self {
        case .seedling:  return "Just getting started. Build your streak!"
        case .rising:    return "3-day streak — momentum is building."
        case .shining:   return "One full week. You're on a roll."
        case .glowing:   return "Two weeks strong. Look at you glow."
        case .radiant:   return "Three weeks. Basically a morning person."
        case .blazing:   return "30 days. You're an absolute machine."
        case .legendary: return "50+ days. Pure solar deity energy."
        }
    }

    var streakThreshold: Int { [0, 3, 7, 14, 21, 30, 50][rawValue] }
    var nextThreshold: Int { SunLevel(rawValue: rawValue + 1)?.streakThreshold ?? 999 }
    var rayCount: Int { [6, 8, 10, 12, 12, 14, 16][rawValue] }
}

// MARK: - Sun Mood

enum SunMood: Equatable {
    case idle, happy, excited, worried, celebrating
}

// MARK: - Repeat Days

enum RepeatDay: String, CaseIterable, Identifiable, Codable {
    case sun = "Sun", mon = "Mon", tue = "Tue", wed = "Wed"
    case thu = "Thu", fri = "Fri", sat = "Sat"

    var id: String { rawValue }

    var weekdayIndex: Int {
        switch self {
        case .sun: return 1; case .mon: return 2; case .tue: return 3
        case .wed: return 4; case .thu: return 5; case .fri: return 6; case .sat: return 7
        }
    }
}

// MARK: - Alarm Model

struct AlarmItem: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    var isEnabled: Bool = true
    var repeatDays: Set<RepeatDay> = [.mon, .tue, .wed, .thu, .fri]
    var checkInIntervalMinutes: Int = 5
    var checkInRounds: Int = 2
    var volume: Float = 0.8
    var ringtoneName: String = "Classic"
    var label: String = ""

    var timeText: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    var daysText: String {
        if repeatDays.isEmpty { return "Once" }
        if repeatDays.count == 7 { return "Every day" }
        if repeatDays == [.mon, .tue, .wed, .thu, .fri] { return "Weekdays" }
        if repeatDays == [.sat, .sun] { return "Weekends" }
        return RepeatDay.allCases.filter { repeatDays.contains($0) }.map { $0.rawValue }.joined(separator: " ")
    }
}

// MARK: - App Route

enum AppRoute: Equatable {
    case onboarding, home, alarmRinging, checkIn, levelUp
}

// MARK: - View Model

@MainActor
final class AlarmAppViewModel: ObservableObject {
    private enum DefaultsKey {
        static let pendingAlarmID = "pendingAlarmID"
        static let pendingAlarmStartedAt = "pendingAlarmStartedAt"
        static let emergencyDismissUseCount = "emergencyDismissUseCount"
        static let emergencyDismissDay = "emergencyDismissDay"
        static let secondChanceAlarmID = "secondChanceAlarmID"
        static let secondChanceDeadline = "secondChanceDeadline"
    }

    private let emergencyBaseTapCount = 25
    private let emergencyTapIncrement = 10
    private let secondChanceWindowSeconds: TimeInterval = 10 * 60

    @Published var route: AppRoute = .onboarding
    @Published var sunMood: SunMood = .idle
    @Published var nfcError: String?
    @Published var isNFCScanning = false
    @Published var isEmergencyDismissActive = false
    @Published var emergencyTapsRemaining = 0
    @Published var emergencyGridPosition = Int.random(in: 0..<25)
    @Published var secondChanceDeadline: Date?
    @Published private(set) var currentCheckInRound = 0

    @Published var wakeStreak: Int = 0 {
        didSet { UserDefaults.standard.set(wakeStreak, forKey: "wakeStreak") }
    }

    // Multiple alarms — persisted as JSON
    @Published var alarms: [AlarmItem] = [] {
        didSet { persistAlarms() }
    }

    // Temporary alarm used during onboarding setup
    @Published var onboardingAlarm = AlarmItem()

    // The alarm that is currently ringing
    private(set) var activeAlarm: AlarmItem?

    let nfcManager = NFCManager()
    let alarmManager = AlarmManager()
    private var cancellables = Set<AnyCancellable>()
    private var secondChanceTimer: Timer?

    init() {
        wakeStreak = UserDefaults.standard.integer(forKey: "wakeStreak")
        secondChanceDeadline = UserDefaults.standard.object(forKey: DefaultsKey.secondChanceDeadline) as? Date
        loadAlarms()
        if !UserDefaults.standard.bool(forKey: "hasCompletedSetup"),
           (!alarms.isEmpty || nfcManager.registeredTagID != nil) {
            UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        }
        route = shouldShowOnboarding ? .onboarding : .home
        UserDefaults.standard.set(Date(), forKey: "lastAppOpenDate")
        let active = alarms.filter(\.isEnabled)
        active.forEach { alarmManager.scheduleAlarm($0, activeAlarmsCount: active.count) }
        NotificationCenter.default
            .publisher(for: .alarmDidFire)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                let id = note.userInfo?["alarmID"] as? String
                self?.triggerAlarmRinging(alarmID: id)
            }
            .store(in: &cancellables)

        // Background timer fires this when the alarm time arrives while the
        // app is kept alive by the silent audio loop.
        alarmManager.onAlarmFired = { [weak self] alarmID in
            self?.triggerAlarmRinging(alarmID: alarmID)
        }
        resolvePendingAlarmIfNeeded()
        resolveExpiredSecondChanceIfNeeded()
        scheduleSecondChanceExpiryTimerIfNeeded()
    }

    // MARK: App lifecycle

    func appDidEnterBackground() {
        let active = alarms.filter { $0.isEnabled }
        guard !active.isEmpty else { return }
        alarmManager.startBackgroundMode(alarms: active)
    }

    func appDidBecomeActive() {
        // Cancel background timers — foreground handles alarms via willPresent delegate
        alarmManager.stopBackgroundMode()
        resolveExpiredSecondChanceIfNeeded()
    }

    // MARK: Persistence

    private func persistAlarms() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: "alarms")
        }
    }

    private func loadAlarms() {
        if let data = UserDefaults.standard.data(forKey: "alarms"),
           let saved = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            alarms = saved
        }
    }

    private var shouldShowOnboarding: Bool {
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
        guard hasCompletedSetup else { return true }
        if alarms.isEmpty { return true }
        guard let lastOpen = UserDefaults.standard.object(forKey: "lastAppOpenDate") as? Date else { return false }
        let inactiveDays = Calendar.current.dateComponents([.day], from: lastOpen, to: Date()).day ?? 0
        return inactiveDays >= 60
    }

    // MARK: Computed

    var sunLevel: SunLevel { .forStreak(wakeStreak) }
    var registeredStickerID: String? { nfcManager.registeredTagID }

    var nextAlarmText: String {
        let enabled = alarms.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return "No alarm" }
        return enabled.sorted { $0.date < $1.date }.first!.timeText
    }

    // MARK: Alarm CRUD

    func addAlarm() {
        alarms.append(AlarmItem())
    }

    private var activeAlarmsCount: Int {
        max(1, alarms.filter(\.isEnabled).count)
    }

    /// Re-schedule every enabled alarm. Call after any change that affects how
    /// the chain budget is divided across alarms (add / enable / disable).
    private func rescheduleAllAlarms() {
        let enabled = alarms.filter(\.isEnabled)
        for alarm in enabled {
            alarmManager.scheduleAlarm(alarm, activeAlarmsCount: enabled.count)
        }
    }

    func updateAlarm(_ alarm: AlarmItem) {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx] = alarm
            alarmManager.scheduleAlarm(alarm, activeAlarmsCount: activeAlarmsCount)
        }
    }

    func deleteAlarm(_ alarm: AlarmItem) {
        alarmManager.cancelAlarm(alarm)
        alarms.removeAll { $0.id == alarm.id }
        rescheduleAllAlarms()
    }

    func toggleAlarm(_ alarm: AlarmItem) {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx].isEnabled.toggle()
            if alarms[idx].isEnabled {
                alarmManager.scheduleAlarm(alarms[idx], activeAlarmsCount: activeAlarmsCount)
            } else {
                alarmManager.cancelAlarm(alarms[idx])
                rescheduleAllAlarms()
            }
        }
    }

    // MARK: Onboarding / Setup

    func requestPermissions() {
        alarmManager.requestPermissions { _ in }
    }

    func startNFCRegistration(onSuccess: @escaping () -> Void) {
        nfcError = nil
        isNFCScanning = true
        nfcManager.registerTag { [weak self] result in
            self?.isNFCScanning = false
            switch result {
            case .success: onSuccess()
            case .failure(let err): self?.nfcError = err.localizedDescription
            }
        }
    }

    func finishSetup() {
        alarms.append(onboardingAlarm)
        alarmManager.scheduleAlarm(onboardingAlarm, activeAlarmsCount: activeAlarmsCount)
        UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        route = .home
    }

    // MARK: Alarm ringing

    func triggerAlarmRinging(alarmID: String?) {
        if let id = alarmID, let alarm = alarms.first(where: { $0.id.uuidString == id }) {
            activeAlarm = alarm
        } else {
            activeAlarm = alarms.first(where: { $0.isEnabled })
        }
        if let id = activeAlarm?.id.uuidString {
            UserDefaults.standard.set(id, forKey: DefaultsKey.pendingAlarmID)
            UserDefaults.standard.set(Date(), forKey: DefaultsKey.pendingAlarmStartedAt)
        }
        currentCheckInRound = 0
        isEmergencyDismissActive = false
        sunMood = .excited
        route = .alarmRinging
        resumeAlarmAudio()
    }

    private func resumeAlarmAudio() {
        alarmManager.startAlarmAudio(
            volume: activeAlarm?.volume ?? 0.8,
            ringtone: activeAlarm?.ringtoneName ?? "Classic"
        )
    }

    func startNFCScanForDismissal() {
        nfcError = nil
        isNFCScanning = true
        nfcManager.validateTagForDismissal { [weak self] matched in
            guard let self else { return }
            self.isNFCScanning = false
            if matched {
                let id = self.activeAlarm?.id.uuidString ?? ""
                self.alarmManager.dismissAlarm(alarmID: id)
                self.clearPendingAlarm()
                self.sunMood = .happy
                self.route = .checkIn
            } else {
                self.nfcError = "Wrong sticker — tap your registered one."
            }
        }
    }

    // MARK: Emergency dismiss

    func beginEmergencyDismiss() {
        resetEmergencyCountIfNeeded()
        let priorUses = UserDefaults.standard.integer(forKey: DefaultsKey.emergencyDismissUseCount)
        emergencyTapsRemaining = emergencyBaseTapCount + priorUses * emergencyTapIncrement
        emergencyGridPosition = Int.random(in: 0..<25)
        isEmergencyDismissActive = true
    }

    func registerEmergencyTap() {
        guard emergencyTapsRemaining > 0 else { return }
        emergencyTapsRemaining -= 1
        emergencyGridPosition = Int.random(in: 0..<25)
        if emergencyTapsRemaining == 0 {
            let id = activeAlarm?.id.uuidString ?? ""
            alarmManager.dismissAlarm(alarmID: id)
            let priorUses = UserDefaults.standard.integer(forKey: DefaultsKey.emergencyDismissUseCount)
            UserDefaults.standard.set(priorUses + 1, forKey: DefaultsKey.emergencyDismissUseCount)
            UserDefaults.standard.set(todayStamp, forKey: DefaultsKey.emergencyDismissDay)
            clearPendingAlarm()
            startSecondChance(for: id)
            isEmergencyDismissActive = false
            sunMood = .worried
            route = .home
        }
    }

    func startNFCScanForSecondChance() {
        resolveExpiredSecondChanceIfNeeded()
        guard hasActiveSecondChance else { return }

        nfcError = nil
        isNFCScanning = true
        nfcManager.validateTagForDismissal { [weak self] matched in
            guard let self else { return }
            self.isNFCScanning = false
            if matched {
                self.completeSecondChanceWake()
            } else {
                self.nfcError = "Wrong sticker — tap your registered one."
            }
        }
    }

    var hasActiveSecondChance: Bool {
        guard let deadline = secondChanceDeadline else { return false }
        return deadline > Date()
    }

    private func startSecondChance(for alarmID: String) {
        let deadline = Date().addingTimeInterval(secondChanceWindowSeconds)
        secondChanceDeadline = deadline
        UserDefaults.standard.set(alarmID, forKey: DefaultsKey.secondChanceAlarmID)
        UserDefaults.standard.set(deadline, forKey: DefaultsKey.secondChanceDeadline)
        scheduleSecondChanceExpiryTimerIfNeeded()
        alarmManager.scheduleSecondChanceNotification(deadline: deadline)
    }

    private func completeSecondChanceWake() {
        clearSecondChance()
        let levelBefore = sunLevel
        wakeStreak += 1
        sunMood = sunLevel != levelBefore ? .celebrating : .happy
        route = sunLevel != levelBefore ? .levelUp : .home
    }

    private func resolveExpiredSecondChanceIfNeeded() {
        guard let deadline = secondChanceDeadline, deadline <= Date() else { return }
        clearSecondChance()
        wakeStreak = 0
        sunMood = .worried
        if route != .onboarding {
            route = .home
        }
    }

    private func resolvePendingAlarmIfNeeded() {
        guard UserDefaults.standard.string(forKey: DefaultsKey.pendingAlarmID) != nil else { return }
        clearPendingAlarm()
        wakeStreak = 0
        sunMood = .worried
        if route != .onboarding {
            route = .home
        }
    }

    private func clearPendingAlarm() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.pendingAlarmID)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.pendingAlarmStartedAt)
    }

    private func clearSecondChance() {
        secondChanceTimer?.invalidate()
        secondChanceTimer = nil
        secondChanceDeadline = nil
        UserDefaults.standard.removeObject(forKey: DefaultsKey.secondChanceAlarmID)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.secondChanceDeadline)
    }

    private func scheduleSecondChanceExpiryTimerIfNeeded() {
        secondChanceTimer?.invalidate()
        guard let deadline = secondChanceDeadline else { return }
        let interval = max(0.1, deadline.timeIntervalSinceNow)
        secondChanceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resolveExpiredSecondChanceIfNeeded()
            }
        }
    }

    private func resetEmergencyCountIfNeeded() {
        let storedDay = UserDefaults.standard.string(forKey: DefaultsKey.emergencyDismissDay)
        guard storedDay != nil, storedDay != todayStamp else { return }
        UserDefaults.standard.set(0, forKey: DefaultsKey.emergencyDismissUseCount)
        UserDefaults.standard.set(todayStamp, forKey: DefaultsKey.emergencyDismissDay)
    }

    private var todayStamp: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    // MARK: Check-in

    var checkInRounds: Int { activeAlarm?.checkInRounds ?? 2 }

    func confirmAwake() {
        currentCheckInRound += 1
        let levelBefore = sunLevel
        if currentCheckInRound >= checkInRounds {
            wakeStreak += 1
            if sunLevel != levelBefore {
                sunMood = .celebrating
                route = .levelUp
            } else {
                sunMood = .happy
                route = .home
            }
        } else {
            sunMood = .happy
            route = .checkIn
        }
    }

    func dismissLevelUp() {
        sunMood = .idle
        route = .home
    }
}
