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
    @Published var route: AppRoute = .onboarding
    @Published var sunMood: SunMood = .idle
    @Published var nfcError: String?
    @Published var isNFCScanning = false
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

    init() {
        wakeStreak = UserDefaults.standard.integer(forKey: "wakeStreak")
        loadAlarms()
        if nfcManager.registeredTagID != nil {
            route = .home
        }
        NotificationCenter.default
            .publisher(for: .alarmDidFire)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                let id = note.userInfo?["alarmID"] as? String
                self?.triggerAlarmRinging(alarmID: id)
            }
            .store(in: &cancellables)
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

    func updateAlarm(_ alarm: AlarmItem) {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx] = alarm
            alarmManager.scheduleAlarm(alarm)
        }
    }

    func deleteAlarm(_ alarm: AlarmItem) {
        alarmManager.cancelAlarm(alarm)
        alarms.removeAll { $0.id == alarm.id }
    }

    func toggleAlarm(_ alarm: AlarmItem) {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx].isEnabled.toggle()
            if alarms[idx].isEnabled {
                alarmManager.scheduleAlarm(alarms[idx])
            } else {
                alarmManager.cancelAlarm(alarms[idx])
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
        alarmManager.scheduleAlarm(onboardingAlarm)
        route = .home
    }

    // MARK: Alarm ringing

    func triggerAlarmRinging(alarmID: String?) {
        if let id = alarmID, let alarm = alarms.first(where: { $0.id.uuidString == id }) {
            activeAlarm = alarm
        } else {
            activeAlarm = alarms.first(where: { $0.isEnabled })
        }
        currentCheckInRound = 0
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
                self.alarmManager.stopAlarmAudio()
                self.sunMood = .happy
                self.route = .checkIn
            } else {
                self.nfcError = "Wrong sticker — tap your registered one."
            }
        }
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
