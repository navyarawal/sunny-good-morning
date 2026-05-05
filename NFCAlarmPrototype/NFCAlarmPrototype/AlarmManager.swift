import AVFoundation
import UserNotifications
import Foundation

final class AlarmManager: NSObject {

    static let ringtoneNames = ["Classic", "Pulse", "Chime", "Urgent", "Gentle"]

    var isAlarmPlaying = false

    private var audioPlayer: AVAudioPlayer?
    private var rampTimer: Timer?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
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
        content.title = "Rise & Tap"
        content.body = "Time to get up! Go find Sunny to stop this."
        content.sound = .default
        content.categoryIdentifier = "ALARM"
        content.userInfo = ["alarmID": alarm.id.uuidString]

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
    }

    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func enqueue(content: UNMutableNotificationContent, components: DateComponents, id: String, repeats: Bool) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - In-App Audio

    func startAlarmAudio(volume: Float = 0.8, ringtone: String = "Classic") {
        guard !isAlarmPlaying else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }

        guard let data = wavData(for: ringtone),
              let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue) else { return }

        let clampedVolume = max(0, min(volume, 1))
        player.numberOfLoops = -1
        player.volume = clampedVolume * 0.2   // start quiet, ramp up
        player.prepareToPlay()
        player.play()

        audioPlayer = player
        isAlarmPlaying = true

        rampVolume(on: player, to: clampedVolume, over: 30)
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

    // MARK: - WAV synthesis

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

    // Classic: ascending 3-beep (880 → 1047 → 1319 Hz)
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

    // Pulse: single clean beep every 1.6 s
    private func pulseSamples(sr: Int) -> [Float] {
        generate(sr: sr, duration: 1.6) { t in
            guard t < 0.25 else { return 0 }
            let env = Float(min(t / 0.01, 1) * min((0.25 - t) / 0.01, 1))
            return Float(sin(2 * .pi * 1000 * t)) * 0.75 * env
        }
    }

    // Chime: descending 3-beep (1319 → 1047 → 880 Hz)
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

    // Urgent: rapid 6 short beeps
    private func urgentSamples(sr: Int) -> [Float] {
        generate(sr: sr, duration: 1.2) { t in
            let slot = t.truncatingRemainder(dividingBy: 0.2)
            guard slot < 0.1 else { return 0 }
            let env = Float(min(slot / 0.005, 1) * min((0.1 - slot) / 0.005, 1))
            return Float(sin(2 * .pi * 1200 * t)) * 0.75 * env
        }
    }

    // Gentle: slow soft long tone
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

    // Build a 16-bit PCM mono WAV blob in memory
    private func makeWAV(samples: [Float], sampleRate: Int) -> Data {
        let int16: [Int16] = samples.map { Int16(max(-32767, min(32767, $0 * 32767))) }
        let dataSize = int16.count * 2
        var wav = Data(capacity: 44 + dataSize)

        func le32(_ v: UInt32) {
            var x = v.littleEndian
            withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) }
        }
        func le16(_ v: UInt16) {
            var x = v.littleEndian
            withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) }
        }

        wav += "RIFF".data(using: .ascii)!;  le32(UInt32(36 + dataSize))
        wav += "WAVE".data(using: .ascii)!
        wav += "fmt ".data(using: .ascii)!;  le32(16); le16(1); le16(1)
        le32(UInt32(sampleRate)); le32(UInt32(sampleRate * 2)); le16(2); le16(16)
        wav += "data".data(using: .ascii)!;  le32(UInt32(dataSize))

        for s in int16 {
            var v = s
            withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) }
        }
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
        }
        handler([.banner, .sound])
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
