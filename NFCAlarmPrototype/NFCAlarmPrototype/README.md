# NFC Alarm Prototype (SwiftUI)

This is a SwiftUI prototype for an NFC alarm experience designed for college-age users.

## What's included

- Onboarding with a sun mascot and first-alarm CTA
- Alarm setup with time picker, music, volume, vibration, repeat days
- Check-in interval + number of rounds
- NFC setup simulation with a generated sticker ID
- Home dashboard with next alarm, sticker status, streak, and sun progression
- Alarm ringing screen with urgent yellow styling
- Check-in flow that simulates "I'm awake" or failed response
- Gamification with levels: baby sun -> happy sun -> cool sun

## Files

- `NFCAlarmPrototypeApp.swift`: App entry
- `Models.swift`: local model + view model + app flow
- `Theme.swift`: palette and button style
- `SunMascotView.swift`: reusable mascot view
- `ContentView.swift`: screen flow and UI

## Notes for real NFC integration

Search for comments in `Models.swift` where Core NFC read/verification logic should be added:

- NFC tag read/write initiation
- Validating scanned tag ID against the saved sticker ID
