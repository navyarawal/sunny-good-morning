# Sunny Alarm Reliability

## Architecture

Sunny now uses three alarm layers:

1. **Primary app-alive path**
   - `AVAudioSession` category `.playback`, mode `.default`, no `.mixWithOthers`.
   - `AVAudioPlayer.numberOfLoops = -1` for infinite in-app ringing.
   - Background audio keep-alive starts when the app backgrounds with active alarms.
   - A watchdog restarts audio after route/volume/interruption glitches.
   - `beginBackgroundTask(withName:)` is started when the alarm rings; if iOS expires it, Sunny posts an immediate fallback notification.

2. **AlarmKit failsafe on iOS 26+**
   - Every enabled Sunny alarm is also scheduled through AlarmKit.
   - AlarmKit is the only public iOS API that can behave like a system alarm if Sunny was force-quit or suspended.
   - When AlarmKit alerts, Sunny opens into the NFC-dismiss flow and schedules a short follow-up AlarmKit ring. If the user stops the system alert and then closes Sunny without scanning, the follow-up rings again.

3. **Local notification chain**
   - Every alarm schedules a chain of custom-sound local notifications as a third fallback.
   - Sounds are generated into `Library/Sounds` under the iOS custom notification sound limit.
   - Critical Alerts are not enabled unless Apple grants the entitlement.

## Apple Limits We Cannot Bypass

- iOS does not provide a public API to programmatically raise system volume.
- `.playback` bypasses the Silent switch while the app audio session is active, but app audio is still affected by the user's output route and system volume.
- If headphones or Bluetooth are connected, iOS routes audio there. Sunny detects this and warns the user.
- AlarmKit can break through Focus/Silent mode, but its system UI can still expose system controls. Sunny responds by keeping the alarm active in-app and scheduling follow-up AlarmKit alerts until NFC/emergency dismissal.
- Local notifications can be cleared by the user; the chain reduces the impact but cannot make notifications impossible to dismiss.
- BGAppRefresh is opportunistic. It improves reliability but cannot be treated as an exact alarm timer.

## Required Capabilities / Entitlements

- Background Modes: `audio`, `fetch`
- `BGTaskSchedulerPermittedIdentifiers`: `UCLA.NFCAlarmPrototype.alarm-refresh`
- NFC: `com.apple.developer.nfc.readersession.formats = TAG`
- Info.plist:
  - `NFCReaderUsageDescription`
  - `NSAlarmKitUsageDescription`
  - `NSSupportsLiveActivities`
- Optional future entitlement:
  - Critical Alerts: `com.apple.developer.usernotifications.critical-alerts` requires Apple approval and is an App Store review risk if the app cannot justify safety/health-critical use.

## Test Matrix

| Scenario | Steps | Expected behavior |
| --- | --- | --- |
| Foreground alarm | Open Sunny, set alarm 1 minute ahead, keep app open. | Alarm screen appears, audio loops until NFC/emergency dismissal. |
| Background app, screen on | Set alarm, press Home/lock but do not force-quit. | Background audio keep-alive plus timer fires; alarm screen appears when opened; audio loops. |
| Locked overnight | Set alarm 8+ hours ahead, lock phone, leave charging. | AlarmKit/local notification chain fires even if the app is suspended. Opening notification shows NFC flow. |
| Force-quit before alarm | Set alarm, swipe Sunny away, wait. | AlarmKit fires on iOS 26+; local notification chain remains as fallback. |
| Memory pressure termination | Set alarm, background app, use other heavy apps. | AlarmKit/local notification fallback fires if Sunny is killed. |
| Never opened after install | Install app but do not launch or schedule anything. | No iOS app can schedule an alarm before first launch/permission; Sunny can only protect alarms after setup has completed. |
| Silent switch on | Set alarm, flip Silent switch, keep app alive. | `.playback` alarm audio still plays while app audio session is alive; AlarmKit fallback also rings. |
| System volume low | Lower volume below ~35%, trigger alarm. | Alarm rings at app gain, and Sunny shows a fullscreen warning telling the user system volume is low. |
| DND / Focus | Enable Focus, set alarm. | AlarmKit can break through on iOS 26+ after authorization; local notifications use Time Sensitive where allowed. |
| Headphones/Bluetooth | Connect audio route, trigger alarm. | Sunny detects route and warns audio may play through headphones/Bluetooth. |
| Notification denied | Deny notifications, set alarm. | App-alive audio and AlarmKit remain. Local notification chain will not alert. |
| AlarmKit denied | Deny AlarmKit permission. | App-alive audio and local notification chain remain. |
| Background App Refresh off | Disable Background App Refresh. | BG refresh layer may not run; AlarmKit and local notification chain remain. |
| Low Power Mode | Enable Low Power Mode. | BG refresh may be throttled; AlarmKit/local notification chain remain. |
| Phone call interruption | Trigger alarm, receive/end call. | Audio interruption handler reactivates `.playback` and restarts alarm audio. |
| Background task expiration | Use debugger/instruments to force expiration while alarm rings. | Immediate fallback notification posts and alarm state remains pending. |
| NFC wrong tag | Scan an unregistered tag. | Alarm keeps ringing, error shows, retry UI remains available. |
| NFC failed angle/case | Attempt bad scan then cancel/retry. | Alarm keeps ringing; failed scan never dismisses. |
| NFC unavailable | Test on simulator/non-NFC device. | NFC error shows; alarm continues until emergency dismissal. |
| Device reboot | Reboot before alarm. | App code cannot run until launch; AlarmKit is the only reliable post-reboot path on iOS 26+. |
