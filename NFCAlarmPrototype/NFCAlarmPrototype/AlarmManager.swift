import AVFoundation
import UserNotifications
import Foundation

final class AlarmManager: NSObject {

    static let ringtoneNames = ["Classic", "Pulse", "Chime", "Urgent", "Gentle"]

    var isAlarmPlaying = false

    // Chain length & spacing — Alarmy's documented force-quit fallback technique.
    // 60 notifications × 30s = 30 min of guaranteed ringing surviving force-quit.
    // iOS caps pending notifications at 64 per app, so we divide by active alarm count
    // in scheduleAlarm() when scheduling to stay safely under the cap.
    private let chainCount = 60
    private let chainSpacing: TimeInterval = 30.0

    // In-app player (loops infinitely while the app process is alive)
    private var audioPlayer: AVAudioPlayer?
    private var rampTimer: Timer?

    // Background keep-alive: silent loop holds the audio session active so iOS
    // doesn't suspend the process. The DispatchWorkItem timer fires the loud
    // alarm at the exact target time.
    private var keepAlivePlayer: AVAudioPlayer?
    private var alarmTriggers: [String: DispatchWorkItem] = [:]
    private let systemAlarmScheduler = SystemAlarmScheduler()

    var onAlarmFired: ((String) -> Void)?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        SoundLoopGenerator.ensureLoops(ringtoneNames: Self.ringtoneNames)
        systemAlarmScheduler.startObservingAlarmUpdates { alarmID in
            NotificationCenter.default.post(
                name: .alarmDidFire,
                object: nil,
                userInfo: ["alarmID": alarmID]
            )
        }
    }

    // MARK: - Permissions

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                Task {
                    let alarmKitGranted = await self.systemAlarmScheduler.requestAuthorizationIfPossible()
                    await MainActor.run { completion(granted || alarmKitGranted) }
                }
            }
    }

    // MARK: - Schedule / Cancel
    //
    // Strategy: schedule a CHAIN of `chainCount` notifications spaced
    // `chainSpacing` apart, each playing the chosen alarm sound. Even if the
    // user force-quits the app, iOS delivers these notifications and plays
    // their sounds — this is the only App-Store-safe technique that survives
    // process termination on iOS 17.

    /// Schedules the chain. `activeAlarmsCount` lets the caller cap chain length so
    /// total pending notifications across all alarms stays under iOS's 64-per-app cap.
    func scheduleAlarm(_ alarm: AlarmItem, activeAlarmsCount: Int = 1) {
        cancelAlarm(alarm)
        guard alarm.isEnabled else { return }
        guard let firstFire = nextFiringDate(for: alarm) else { return }

        let soundFilename = notificationSoundFileName(for: alarm.ringtoneName)
        let sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundFilename))

        // Cap so multiple alarms don't exceed iOS's 64-pending limit
        let cap = max(1, chainCount / max(1, activeAlarmsCount))

        for i in 0..<cap {
            let fireDate = firstFire.addingTimeInterval(Double(i) * chainSpacing)
            let delay = fireDate.timeIntervalSinceNow
            guard delay > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = i == 0 ? "⏰ Rise & Tap" : "Still ringing — find Sunny!"
            content.body = "Get up and tap your sticker to dismiss."
            content.categoryIdentifier = "ALARM"
            content.userInfo = [
                "alarmID": alarm.id.uuidString,
                "chainIndex": i,
                "ringtone": alarm.ringtoneName,
                "volume": alarm.volume
            ]
            content.interruptionLevel = .timeSensitive
            content.sound = sound
            // Unique threadIdentifier per chain link prevents iOS from collapsing
            // the rapid-fire notifications and suppressing repeat sounds.
            content.threadIdentifier = "alarm-\(alarm.id.uuidString)-\(i)"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let id = "alarm-\(alarm.id.uuidString)-chain-\(i)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }

        Task { [systemAlarmScheduler] in
            let didScheduleSystemAlarm = await systemAlarmScheduler.schedule(alarm, soundName: soundFilename)
            if didScheduleSystemAlarm {
                self.cancelChain(alarmID: alarm.id.uuidString)
            }
        }
    }

    func cancelAlarm(_ alarm: AlarmItem) {
        cancelChain(alarmID: alarm.id.uuidString)
        systemAlarmScheduler.cancel(id: alarm.id)
        alarmTriggers[alarm.id.uuidString]?.cancel()
        alarmTriggers.removeValue(forKey: alarm.id.uuidString)
    }

    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        alarmTriggers.values.forEach { $0.cancel() }
        alarmTriggers.removeAll()
    }

    /// Called when the user successfully dismisses the alarm. Cancels all
    /// remaining chain notifications AND clears delivered ones from the
    /// notification center so the user isn't bombarded.
    func dismissAlarm(alarmID: String) {
        stopAlarmAudio()
        cancelChain(alarmID: alarmID)
        if let id = UUID(uuidString: alarmID) {
            systemAlarmScheduler.stop(id: id)
        }
        alarmTriggers[alarmID]?.cancel()
        alarmTriggers.removeValue(forKey: alarmID)
        if #available(iOS 16.2, *) {
            LiveActivityController.shared.end(alarmID: alarmID)
        }
    }

    func scheduleSecondChanceNotification(deadline: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Second chance active"
        content.body = "Scan Sunny by \(deadline.formatted(date: .omitted, time: .shortened)) and this still counts as an on-time wake-up."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "second-chance-active",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Starts the Live Activity for a firing alarm. Idempotent — the controller
    /// no-ops if an Activity already exists for this alarmID. Call from both
    /// the foreground notification path and the background DispatchWorkItem.
    private func startLiveActivity(alarmID: String, ringtone: String) {
        if #available(iOS 16.2, *) {
            LiveActivityController.shared.start(alarmID: alarmID, label: "Rise & Tap", ringtone: ringtone)
        }
    }

    private func cancelChain(alarmID: String) {
        let prefix = "alarm-\(alarmID)-chain-"
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        center.getDeliveredNotifications { notes in
            let ids = notes.map(\.request.identifier).filter { $0.hasPrefix(prefix) }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    private func registerNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_ALARM",
            title: "Open Alarm",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "ALARM",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Background mode

    func startBackgroundMode(alarms: [AlarmItem]) {
        startKeepAlive()
        for alarm in alarms where alarm.isEnabled {
            scheduleAlarmTrigger(alarm)
        }
    }

    func stopBackgroundMode() {
        stopKeepAlive()
        alarmTriggers.values.forEach { $0.cancel() }
        alarmTriggers.removeAll()
    }

    private func startKeepAlive() {
        guard keepAlivePlayer == nil else { return }
        let samples = [Float](repeating: 0, count: 44100)
        let data = makeWAV(samples: samples, sampleRate: 44100)
        guard let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()
        keepAlivePlayer = player
    }

    private func stopKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        if !isAlarmPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func scheduleAlarmTrigger(_ alarm: AlarmItem) {
        guard let date = nextFiringDate(for: alarm) else { return }
        let delay = date.timeIntervalSince(.now)
        guard delay > 0 else { return }

        let id = alarm.id.uuidString
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.startAlarmAudio(volume: alarm.volume, ringtone: alarm.ringtoneName)
            self.startLiveActivity(alarmID: id, ringtone: alarm.ringtoneName)
            self.onAlarmFired?(id)
        }
        alarmTriggers[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func nextFiringDate(for alarm: AlarmItem) -> Date? {
        let cal = Calendar.current
        let now = Date()
        let timeComps = cal.dateComponents([.hour, .minute], from: alarm.date)

        if alarm.repeatDays.isEmpty {
            var dc = cal.dateComponents([.year, .month, .day], from: now)
            dc.hour = timeComps.hour; dc.minute = timeComps.minute; dc.second = 0
            if let d = cal.date(from: dc), d > now { return d }
            // One-time alarm with a time already past today → fire tomorrow
            return cal.date(byAdding: .day, value: 1, to: cal.date(from: dc) ?? now)
        }

        for ahead in 0..<8 {
            guard let candidate = cal.date(byAdding: .day, value: ahead, to: now) else { continue }
            let weekday = cal.component(.weekday, from: candidate)
            guard let rd = RepeatDay.allCases.first(where: { $0.weekdayIndex == weekday }),
                  alarm.repeatDays.contains(rd) else { continue }
            var dc = cal.dateComponents([.year, .month, .day], from: candidate)
            dc.hour = timeComps.hour; dc.minute = timeComps.minute; dc.second = 0
            if let d = cal.date(from: dc), d > now { return d }
        }
        return nil
    }

    // MARK: - In-App Audio (loops loud while app is alive — bypasses mute switch)

    func startAlarmAudio(volume: Float = 0.8, ringtone: String = "Classic") {
        guard !isAlarmPlaying else { return }
        guard let url = bundleURL(for: ringtone) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }

        let target = max(0, min(volume, 1))
        player.numberOfLoops = -1
        player.volume = target * 0.2  // start at 20%, ramp to full over 30s
        player.prepareToPlay()
        player.play()

        audioPlayer = player
        isAlarmPlaying = true
        rampVolume(on: player, to: target, over: 30)
    }

    func previewSound(volume: Float = 0.8, ringtone: String = "Classic") {
        audioPlayer?.stop()
        rampTimer?.invalidate()
        rampTimer = nil
        audioPlayer = nil

        guard let url = bundleURL(for: ringtone) else { return }

        do {
            // .playback bypasses the silent/mute switch — preview rings even if muted
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = max(0, min(volume, 1))
        player.numberOfLoops = 0
        player.prepareToPlay()
        player.play()
        audioPlayer = player

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard self?.isAlarmPlaying == false else { return }
            self?.audioPlayer?.stop()
            self?.audioPlayer = nil
        }
    }

    func stopAlarmAudio() {
        rampTimer?.invalidate()
        rampTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isAlarmPlaying = false
        if keepAlivePlayer == nil {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func rampVolume(on player: AVAudioPlayer, to target: Float, over duration: TimeInterval) {
        rampTimer?.invalidate()
        let interval: TimeInterval = 0.5
        let steps = Int(duration / interval)
        let start = player.volume
        let step = (target - start) / Float(steps)
        var count = 0
        rampTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self, weak player] t in
            guard let player else { t.invalidate(); return }
            count += 1
            player.volume = min(target, start + step * Float(count))
            if count >= steps { t.invalidate(); self?.rampTimer = nil }
        }
    }

    // MARK: - Bundled sound resolution

    private func bundleURL(for ringtone: String) -> URL? {
        Bundle.main.url(forResource: "rise_\(ringtone.lowercased())", withExtension: "wav")
    }

    private func notificationSoundFileName(for ringtone: String) -> String {
        let normalized = ringtone.lowercased()
        if Self.ringtoneNames.map({ $0.lowercased() }).contains(normalized) {
            return "rise_\(normalized).wav"
        }
        return "rise_classic.wav"
    }

    // MARK: - WAV builder (only used for the silent keep-alive buffer now)

    private func makeWAV(samples: [Float], sampleRate: Int) -> Data {
        let int16: [Int16] = samples.map { Int16(max(-32767, min(32767, $0 * 32767))) }
        let dataSize = int16.count * 2
        var wav = Data(capacity: 44 + dataSize)
        func le32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) } }
        func le16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) } }
        wav += "RIFF".data(using: .ascii)!;  le32(UInt32(36 + dataSize))
        wav += "WAVE".data(using: .ascii)!
        wav += "fmt ".data(using: .ascii)!;  le32(16); le16(1); le16(1)
        le32(UInt32(sampleRate)); le32(UInt32(sampleRate * 2)); le16(2); le16(16)
        wav += "data".data(using: .ascii)!;  le32(UInt32(dataSize))
        for s in int16 { var v = s; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
        return wav
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AlarmManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.categoryIdentifier == "ALARM" {
            let alarmID = notification.request.content.userInfo["alarmID"] as? String ?? ""
            let chainIndex = notification.request.content.userInfo["chainIndex"] as? Int ?? 0
            let ringtone = notification.request.content.userInfo["ringtone"] as? String ?? "Classic"
            DispatchQueue.main.async { [weak self] in
                if chainIndex == 0 {
                    NotificationCenter.default.post(name: .alarmDidFire, object: nil,
                                                   userInfo: ["alarmID": alarmID])
                    self?.startLiveActivity(alarmID: alarmID, ringtone: ringtone)
                }
            }
            // First chain notification: in-app loop takes over (suppress notif sound)
            // Later chain notifications: silently — audio is already looping
            handler([])
        } else {
            handler([.banner, .sound])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        if response.notification.request.content.categoryIdentifier == "ALARM" {
            let alarmID = response.notification.request.content.userInfo["alarmID"] as? String ?? ""
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .alarmDidFire, object: nil,
                                               userInfo: ["alarmID": alarmID])
            }
        }
        handler()
    }
}

extension Notification.Name {
    static let alarmDidFire = Notification.Name("alarmDidFire")
}
