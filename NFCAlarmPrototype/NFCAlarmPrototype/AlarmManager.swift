import AVFoundation
import UserNotifications
import Foundation

final class AlarmManager: NSObject {

    static let ringtoneNames = ["Classic", "Pulse", "Chime", "Urgent", "Gentle"]

    var isAlarmPlaying = false

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = max(0, min(volume, 1))

        guard let buffer = buildBuffer(ringtone: ringtone, format: format) else { return }
        do { try engine.start() } catch { return }

        node.scheduleBuffer(buffer, at: nil, options: .loops)
        node.play()
        audioEngine = engine
        playerNode = node
        isAlarmPlaying = true
    }

    func previewSound(volume: Float = 0.8, ringtone: String = "Classic") {
        stopAlarmAudio()
        startAlarmAudio(volume: volume, ringtone: ringtone)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.stopAlarmAudio()
        }
    }

    func stopAlarmAudio() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        isAlarmPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Ringtone Buffers

    private func buildBuffer(ringtone: String, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        switch ringtone {
        case "Pulse":   return buildPulseBuffer(format: format)
        case "Chime":   return buildChimeBuffer(format: format)
        case "Urgent":  return buildUrgentBuffer(format: format)
        case "Gentle":  return buildGentleBuffer(format: format)
        default:        return buildClassicBuffer(format: format)
        }
    }

    // Classic: ascending 3-beep (880 → 1047 → 1319 Hz)
    private func buildClassicBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(format: format, duration: 2.0) { t in
            struct B { var s, e, f: Double }
            let beeps = [B(s:0.00,e:0.14,f:880), B(s:0.20,e:0.34,f:1047), B(s:0.40,e:0.54,f:1319)]
            for b in beeps where t >= b.s && t < b.e {
                let lt = t - b.s; let dur = b.e - b.s
                return Float(sin(2 * .pi * b.f * t)) * 0.75 * Float(min(lt/0.01,1) * min((dur-lt)/0.01,1))
            }
            return 0
        }
    }

    // Pulse: single clean beep every 0.8s
    private func buildPulseBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(format: format, duration: 1.6) { t in
            let on = t < 0.25
            guard on else { return 0 }
            let env = Float(min(t/0.01,1) * min((0.25-t)/0.01,1))
            return Float(sin(2 * .pi * 1000 * t)) * 0.75 * env
        }
    }

    // Chime: descending 3-beep (1319 → 1047 → 880 Hz)
    private func buildChimeBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(format: format, duration: 2.0) { t in
            struct B { var s, e, f: Double }
            let beeps = [B(s:0.00,e:0.14,f:1319), B(s:0.20,e:0.34,f:1047), B(s:0.40,e:0.54,f:880)]
            for b in beeps where t >= b.s && t < b.e {
                let lt = t - b.s; let dur = b.e - b.s
                return Float(sin(2 * .pi * b.f * t)) * 0.75 * Float(min(lt/0.01,1) * min((dur-lt)/0.01,1))
            }
            return 0
        }
    }

    // Urgent: rapid fire 6 short beeps
    private func buildUrgentBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(format: format, duration: 1.2) { t in
            let slot = t.truncatingRemainder(dividingBy: 0.2)
            guard slot < 0.1 else { return 0 }
            let env = Float(min(slot/0.005,1) * min((0.1-slot)/0.005,1))
            return Float(sin(2 * .pi * 1200 * t)) * 0.75 * env
        }
    }

    // Gentle: slow soft single long tone
    private func buildGentleBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(format: format, duration: 3.0) { t in
            guard t < 1.2 else { return 0 }
            let env = Float(min(t/0.1,1) * min((1.2-t)/0.3,1))
            return Float(sin(2 * .pi * 660 * t)) * 0.55 * env
        }
    }

    private func makeBuffer(format: AVAudioFormat, duration: Double, sample: (Double) -> Float) -> AVAudioPCMBuffer? {
        let sr = 44100.0
        let frameCount = AVAudioFrameCount(sr * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        let ch = buf.floatChannelData![0]
        for f in 0..<Int(frameCount) { ch[f] = sample(Double(f) / sr) }
        return buf
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
