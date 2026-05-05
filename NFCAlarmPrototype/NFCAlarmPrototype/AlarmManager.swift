import AVFoundation
import UserNotifications
import Foundation

final class AlarmManager: NSObject {

    static let ringtoneNames = ["Classic", "Pulse", "Chime", "Urgent", "Gentle"]

    var isAlarmPlaying = false

    // In-app alarm player (looping, bypasses mute switch via .playback category)
    private var audioPlayer: AVAudioPlayer?
    private var rampTimer: Timer?

    // Background keep-alive: silent loop that prevents iOS from suspending the app.
    // While this plays, DispatchWorkItems can fire at exact alarm times even when
    // the screen is locked.
    private var keepAlivePlayer: AVAudioPlayer?
    private var alarmTriggers: [String: DispatchWorkItem] = [:]

    // Callback set by ViewModel so the background trigger can update app state
    var onAlarmFired: ((String) -> Void)?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        writeNotificationSounds()
    }

    // MARK: - Permissions

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    // MARK: - Schedule / Cancel

    func scheduleAlarm(_ alarm: AlarmItem) {
        cancelAlarm(alarm)
        guard alarm.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "⏰ Rise & Tap"
        content.body = "Get up and find Sunny!"
        content.categoryIdentifier = "ALARM"
        content.userInfo = ["alarmID": alarm.id.uuidString]
        content.interruptionLevel = .timeSensitive
        // Use .defaultRingtone — louder than .default, no custom file needed
        content.sound = .defaultRingtone

        let comps = Calendar.current.dateComponents([.hour, .minute], from: alarm.date)
        let prefix = alarm.id.uuidString

        if alarm.repeatDays.isEmpty {
            enqueue(content: content, components: comps, id: "alarm-\(prefix)-once", repeats: false)
        } else {
            for day in alarm.repeatDays {
                var dc = comps
                dc.weekday = day.weekdayIndex
                enqueue(content: content, components: dc, id: "alarm-\(prefix)-\(day.rawValue)", repeats: true)
            }
        }
    }

    func cancelAlarm(_ alarm: AlarmItem) {
        var ids = ["alarm-\(alarm.id.uuidString)-once"]
        for day in RepeatDay.allCases {
            ids.append("alarm-\(alarm.id.uuidString)-\(day.rawValue)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)

        alarmTriggers[alarm.id.uuidString]?.cancel()
        alarmTriggers.removeValue(forKey: alarm.id.uuidString)
    }

    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        alarmTriggers.values.forEach { $0.cancel() }
        alarmTriggers.removeAll()
    }

    private func enqueue(content: UNMutableNotificationContent, components: DateComponents, id: String, repeats: Bool) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Background mode
    //
    // Plays a silent loop so iOS keeps the process alive. When the alarm time
    // arrives a DispatchWorkItem fires startAlarmAudio() directly — this uses
    // AVAudioSession(.playback) which bypasses the mute/silent switch, so the
    // alarm rings even if the user has silent mode on.

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

        // One second of silence, looped forever. The AVAudioSession being active
        // is what keeps the app alive — the actual audio content is inaudible.
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
            return nil
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

    // MARK: - In-App Audio

    func startAlarmAudio(volume: Float = 0.8, ringtone: String = "Classic") {
        guard !isAlarmPlaying else { return }

        do {
            // .playback bypasses the mute/silent switch — alarm rings regardless
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        guard let data = wavData(for: ringtone),
              let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue) else { return }

        let clamped = max(0, min(volume, 1))
        player.numberOfLoops = -1
        player.volume = clamped * 0.2
        player.prepareToPlay()
        player.play()

        audioPlayer = player
        isAlarmPlaying = true

        rampVolume(on: player, to: clamped, over: 30)
    }

    func previewSound(volume: Float = 0.8, ringtone: String = "Classic") {
        audioPlayer?.stop()
        rampTimer?.invalidate()
        rampTimer = nil
        audioPlayer = nil

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        guard let data = wavData(for: ringtone),
              let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue) else { return }

        player.volume = max(0, min(volume, 1))
        player.prepareToPlay()
        player.play()
        audioPlayer = player

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
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
        // Only deactivate if keep-alive isn't running
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

    // MARK: - Notification sound files
    //
    // Writes 29-second WAV files to Library/Sounds so the OS can play them as
    // notification sounds even when the app is not running.

    private func writeNotificationSounds() {
        guard let dir = soundsDirectory() else { return }
        let sr = 44100
        let dur = 29.0

        let tones: [(String, [Float])] = [
            ("classic", tile(classicSamples(sr: sr), to: dur, sr: sr)),
            ("pulse",   tile(pulseSamples(sr: sr),   to: dur, sr: sr)),
            ("chime",   tile(chimeSamples(sr: sr),   to: dur, sr: sr)),
            ("urgent",  tile(urgentSamples(sr: sr),  to: dur, sr: sr)),
            ("gentle",  tile(gentleSamples(sr: sr),  to: dur, sr: sr)),
        ]
        for (name, samples) in tones {
            let url = dir.appendingPathComponent("rise_alarm_\(name).wav")
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            try? makeWAV(samples: samples, sampleRate: sr).write(to: url)
        }
    }

    private func soundsDirectory() -> URL? {
        guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let dir = lib.appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func tile(_ pattern: [Float], to duration: Double, sr: Int) -> [Float] {
        let total = Int(Double(sr) * duration)
        var result = [Float](repeating: 0, count: total)
        var offset = 0
        while offset < total {
            let chunk = min(pattern.count, total - offset)
            result.replaceSubrange(offset..<(offset + chunk), with: pattern[0..<chunk])
            offset += pattern.count
        }
        return result
    }

    // MARK: - Short WAV clips for in-app looping

    private func wavData(for ringtone: String) -> Data? {
        let sr = 44100
        let samples: [Float]
        switch ringtone {
        case "Pulse":   samples = pulseSamples(sr: sr)
        case "Chime":   samples = chimeSamples(sr: sr)
        case "Urgent":  samples = urgentSamples(sr: sr)
        case "Gentle":  samples = gentleSamples(sr: sr)
        default:        samples = classicSamples(sr: sr)
        }
        return makeWAV(samples: samples, sampleRate: sr)
    }

    // MARK: - Tone generators

    private func classicSamples(sr: Int) -> [Float] {
        typealias B = (s: Double, e: Double, f: Double)
        let beeps: [B] = [(0.00, 0.14, 880), (0.20, 0.34, 1047), (0.40, 0.54, 1319)]
        return generate(sr: sr, duration: 2.0) { t in
            for b in beeps where t >= b.s && t < b.e {
                let lt = t - b.s; let dur = b.e - b.s
                return Float(sin(2 * .pi * b.f * t)) * 0.75 *
                    Float(min(lt / 0.01, 1) * min((dur - lt) / 0.01, 1))
            }
            return 0
        }
    }

    private func pulseSamples(sr: Int) -> [Float] {
        generate(sr: sr, duration: 1.6) { t in
            guard t < 0.25 else { return 0 }
            let env = Float(min(t / 0.01, 1) * min((0.25 - t) / 0.01, 1))
            return Float(sin(2 * .pi * 1000 * t)) * 0.75 * env
        }
    }

    private func chimeSamples(sr: Int) -> [Float] {
        typealias B = (s: Double, e: Double, f: Double)
        let beeps: [B] = [(0.00, 0.14, 1319), (0.20, 0.34, 1047), (0.40, 0.54, 880)]
        return generate(sr: sr, duration: 2.0) { t in
            for b in beeps where t >= b.s && t < b.e {
                let lt = t - b.s; let dur = b.e - b.s
                return Float(sin(2 * .pi * b.f * t)) * 0.75 *
                    Float(min(lt / 0.01, 1) * min((dur - lt) / 0.01, 1))
            }
            return 0
        }
    }

    private func urgentSamples(sr: Int) -> [Float] {
        generate(sr: sr, duration: 1.2) { t in
            let slot = t.truncatingRemainder(dividingBy: 0.2)
            guard slot < 0.1 else { return 0 }
            let env = Float(min(slot / 0.005, 1) * min((0.1 - slot) / 0.005, 1))
            return Float(sin(2 * .pi * 1200 * t)) * 0.75 * env
        }
    }

    private func gentleSamples(sr: Int) -> [Float] {
        generate(sr: sr, duration: 3.0) { t in
            guard t < 1.2 else { return 0 }
            let env = Float(min(t / 0.1, 1) * min((1.2 - t) / 0.3, 1))
            return Float(sin(2 * .pi * 660 * t)) * 0.55 * env
        }
    }

    private func generate(sr: Int, duration: Double, sample: (Double) -> Float) -> [Float] {
        let count = Int(Double(sr) * duration)
        return (0..<count).map { sample(Double($0) / Double(sr)) }
    }

    // MARK: - 16-bit PCM WAV builder

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
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .alarmDidFire, object: nil, userInfo: ["alarmID": alarmID])
            }
            // In-app audio takes over — suppress the notification sound to avoid overlap
            handler([.banner])
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
                NotificationCenter.default.post(name: .alarmDidFire, object: nil, userInfo: ["alarmID": alarmID])
            }
        }
        handler()
    }
}

extension Notification.Name {
    static let alarmDidFire = Notification.Name("alarmDidFire")
}
