import SwiftUI

// MARK: - Root router

struct ContentView: View {
    @EnvironmentObject private var vm: AlarmAppViewModel

    var body: some View {
        ZStack {
            switch vm.route {
            case .onboarding:
                OnboardingFlow()
            case .home:
                MainTabView()
            case .alarmRinging:
                AlarmRingingScreen()
                    .transition(.opacity)
            case .checkIn:
                CheckInScreen()
                    .transition(.move(edge: .bottom))
            case .levelUp:
                LevelUpScreen()
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.route)
    }
}

// MARK: - Onboarding

private struct OnboardingFlow: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var step = 0

    var body: some View {
        ZStack {
            AppTheme.homeGradient(hour: AppTheme.currentHour).ignoresSafeArea()
            switch step {
            case 0: WelcomeStep { step = 1 }
            case 1: AlarmSetupStep { step = 2 }
            case 2: NFCSetupStep { vm.finishSetup() }
            default: EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
}

private struct WelcomeStep: View {
    var onContinue: () -> Void
    @EnvironmentObject private var vm: AlarmAppViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            SunMascotView(level: .seedling, mood: .idle, size: 150)
                .padding(.bottom, 28)
            Text("Rise & Tap")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textDark)
            Text("Wake up for real.\nFind Sunny to prove you're out of bed.")
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textMedium)
                .padding(.top, 10)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button("Get Started") {
                    vm.requestPermissions()
                    onContinue()
                }
                .buttonStyle(PrimaryButtonStyle(color: AppTheme.textDark))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

private struct AlarmSetupStep: View {
    var onContinue: () -> Void
    @EnvironmentObject private var vm: AlarmAppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Set Your Alarm")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textDark)
                    .padding(.top, 56)

                SunCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Wake Time", systemImage: "clock.fill")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.textMedium)
                        DatePicker("", selection: $vm.onboardingAlarm.date, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                }

                SunCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Repeat Days", systemImage: "calendar")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.textMedium)
                        RepeatDayPicker(days: $vm.onboardingAlarm.repeatDays)
                    }
                }

                SunCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Check-In Safety Net", systemImage: "checkmark.shield.fill")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.textMedium)
                        Stepper(
                            "Rounds: \(vm.onboardingAlarm.checkInRounds)",
                            value: $vm.onboardingAlarm.checkInRounds, in: 1...5
                        )
                        .font(.system(.subheadline, design: .rounded))
                        Text("After each tap, Sunny will check back in \(vm.onboardingAlarm.checkInIntervalMinutes) min.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(AppTheme.textLight)
                    }
                }

                Button("Next: Set Up Sunny's Spot") { onContinue() }
                    .buttonStyle(PrimaryButtonStyle(color: AppTheme.sunAmber))
                    .padding(.top, 4)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct NFCSetupStep: View {
    var onDone: () -> Void
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var registered = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            SunMascotView(level: .seedling, mood: registered ? .happy : .idle, size: 130)
                .padding(.bottom, 28)

            Text("Set Up Sunny's Spot")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textDark)
            Text("Put Sunny's sticker somewhere far from your bed — bathroom, kitchen, front door.\nTap below to link it.")
                .font(.system(.subheadline, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textMedium)
                .padding(.top, 10)
                .padding(.horizontal, 28)

            if let id = vm.registeredStickerID, registered {
                SunCard {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sunny's spot is set!")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                            Text("ID: \(id)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppTheme.textLight)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            if let err = vm.nfcError {
                Text(err)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.top, 12)
            }

            Spacer()

            VStack(spacing: 12) {
                if !registered {
                    Button(vm.isNFCScanning ? "Scanning…" : "Link Sunny's Spot") {
                        vm.startNFCRegistration { registered = true }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: AppTheme.sunAmber))
                    .disabled(vm.isNFCScanning)
                }

                if registered {
                    Button("Let's go!") { onDone() }
                        .buttonStyle(PrimaryButtonStyle(color: AppTheme.textDark))
                } else {
                    Button("Skip for now") { onDone() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Main Tab View

private struct MainTabView: View {
    var body: some View {
        TabView {
            HomeTab()
                .tabItem { Label("Home", systemImage: "sun.max.fill") }
            AlarmTab()
                .tabItem { Label("Alarm", systemImage: "alarm.fill") }
            StatsTab()
                .tabItem { Label("Growth", systemImage: "chart.bar.fill") }
        }
        .tint(AppTheme.sunAmber)
    }
}

// MARK: - Home Tab

private struct HomeTab: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    private let hour = AppTheme.currentHour

    var body: some View {
        ZStack {
            AppTheme.homeGradient(hour: hour).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppTheme.greeting(hour: hour))
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 32)

                    // Mascot
                    SunMascotView(level: vm.sunLevel, mood: vm.sunMood, size: 172)
                        .padding(.bottom, 16)

                    // Level badge + streak
                    VStack(spacing: 6) {
                        Text(vm.sunLevel.title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.white)
                        streakPill
                    }
                    .padding(.bottom, 32)

                    // Info cards
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            infoCard(
                                icon: "alarm.fill",
                                title: "Next Alarm",
                                value: vm.nextAlarmText,
                                accent: AppTheme.sunAmber
                            )
                            infoCard(
                                icon: vm.registeredStickerID == nil ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                                title: "Sunny's Spot",
                                value: vm.registeredStickerID == nil ? "Not set up" : "Ready",
                                accent: vm.registeredStickerID == nil ? .orange : .green
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var streakPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(vm.wakeStreak) day streak")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func infoCard(icon: String, title: String, value: String, accent: Color) -> some View {
        SunCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .font(.title3)
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.textLight)
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textDark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Alarm Tab

private struct AlarmTab: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var editingAlarm: AlarmItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()

                Group {
                    if vm.alarms.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(vm.alarms) { alarm in
                                AlarmRow(alarm: alarm) {
                                    editingAlarm = alarm
                                } onToggle: {
                                    vm.toggleAlarm(alarm)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        vm.deleteAlarm(alarm)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }

                            // NFC sticker section at bottom of list
                            nfcSection
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Alarms")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.addAlarm()
                        // Open the new alarm for editing right away
                        if let newest = vm.alarms.last { editingAlarm = newest }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .tint(AppTheme.sunAmber)
                }
            }
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditSheet(alarm: alarm) { updated in
                    vm.updateAlarm(updated)
                    editingAlarm = nil
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "alarm")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textLight)
            Text("No alarms yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.textDark)
            Text("Tap + to add your first alarm.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.textMedium)
        }
    }

    private var nfcSection: some View {
        SunCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Sunny's Spot", systemImage: "wave.3.right")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textMedium)
                if let id = vm.registeredStickerID {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sunny's spot saved")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Text(id)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppTheme.textLight)
                        }
                    }
                } else {
                    Text("Sunny's spot isn't set up yet.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.textLight)
                }
                Button(vm.isNFCScanning ? "Scanning…" : (vm.registeredStickerID == nil ? "Set Up Sunny's Spot" : "Move Sunny's Spot")) {
                    vm.startNFCRegistration { }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(vm.isNFCScanning)

                if let err = vm.nfcError {
                    Text(err).font(.system(.caption, design: .rounded)).foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Alarm Row

private struct AlarmRow: View {
    let alarm: AlarmItem
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        SunCard {
            HStack(spacing: 14) {
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alarm.timeText)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(alarm.isEnabled ? AppTheme.textDark : AppTheme.textLight)
                        Text(alarm.daysText)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(AppTheme.textMedium)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: { _ in onToggle() }))
                    .tint(AppTheme.sunAmber)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Alarm Edit Sheet

private struct AlarmEditSheet: View {
    @State private var alarm: AlarmItem
    let onSave: (AlarmItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var volumeDebounce: DispatchWorkItem?

    init(alarm: AlarmItem, onSave: @escaping (AlarmItem) -> Void) {
        _alarm = State(initialValue: alarm)
        self.onSave = onSave
    }

    private func previewCurrent() {
        vm.alarmManager.previewSound(volume: alarm.volume, ringtone: alarm.ringtoneName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        SunCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Wake Time", systemImage: "clock.fill")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(AppTheme.textMedium)
                                DatePicker("", selection: $alarm.date, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        SunCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Repeat", systemImage: "calendar")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(AppTheme.textMedium)
                                RepeatDayPicker(days: $alarm.repeatDays)
                            }
                        }

                        SunCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Check-In Rounds", systemImage: "checkmark.shield.fill")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(AppTheme.textMedium)
                                Stepper(
                                    "\(alarm.checkInRounds) round\(alarm.checkInRounds == 1 ? "" : "s")",
                                    value: $alarm.checkInRounds, in: 1...5
                                )
                                .font(.system(.subheadline, design: .rounded))
                                Text("Sunny will check back in \(alarm.checkInIntervalMinutes) min after each tap.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(AppTheme.textLight)
                            }
                        }

                        SunCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Volume", systemImage: "speaker.wave.2.fill")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(AppTheme.textMedium)
                                HStack(spacing: 10) {
                                    Image(systemName: "speaker.fill")
                                        .foregroundStyle(AppTheme.textLight)
                                        .font(.caption)
                                    Slider(value: $alarm.volume, in: 0...1)
                                        .tint(AppTheme.sunAmber)
                                        .onChange(of: alarm.volume) { _, newValue in
                                            volumeDebounce?.cancel()
                                            let work = DispatchWorkItem { previewCurrent() }
                                            volumeDebounce = work
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
                                        }
                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundStyle(AppTheme.textLight)
                                        .font(.caption)
                                }
                            }
                        }

                        SunCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Ringtone", systemImage: "music.note")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(AppTheme.textMedium)
                                ForEach(AlarmManager.ringtoneNames, id: \.self) { name in
                                    Button {
                                        alarm.ringtoneName = name
                                        previewCurrent()
                                    } label: {
                                        HStack {
                                            Text(name)
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundStyle(AppTheme.textDark)
                                            Spacer()
                                            if alarm.ringtoneName == name {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(AppTheme.sunAmber)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if name != AlarmManager.ringtoneNames.last {
                                        Divider()
                                    }
                                }
                            }
                        }

                        Button("Save") {
                            onSave(alarm)
                        }
                        .buttonStyle(PrimaryButtonStyle(color: AppTheme.textDark))
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(AppTheme.sunAmber)
                }
            }
        }
    }
}

// MARK: - Stats Tab

private struct StatsTab: View {
    @EnvironmentObject private var vm: AlarmAppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Mascot + level
                        SunCard {
                            VStack(spacing: 16) {
                                SunMascotView(level: vm.sunLevel, mood: vm.sunMood, size: 120)
                                Text(vm.sunLevel.title)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(AppTheme.textDark)
                                Text(vm.sunLevel.subtitle)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.textMedium)
                                    .multilineTextAlignment(.center)

                                // Progress to next level
                                if vm.sunLevel != .legendary {
                                    levelProgressBar
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }

                        // Streak card
                        SunCard {
                            HStack(spacing: 16) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(vm.wakeStreak)")
                                        .font(.system(size: 36, weight: .black, design: .rounded))
                                        .foregroundStyle(AppTheme.textDark)
                                    Text("day streak")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(AppTheme.textMedium)
                                }
                                Spacer()
                            }
                        }

                        // All levels timeline
                        SunCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("All Levels")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(AppTheme.textDark)
                                ForEach(SunLevel.allCases, id: \.rawValue) { lvl in
                                    levelRow(lvl)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Growth")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var levelProgressBar: some View {
        let current = vm.sunLevel
        let threshold = current.streakThreshold
        let nextThreshold = current.nextThreshold
        let progress = Double(vm.wakeStreak - threshold) / Double(nextThreshold - threshold)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(vm.wakeStreak) / \(nextThreshold) days")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textMedium)
                Spacer()
                Text("Next: \(SunLevel(rawValue: vm.sunLevel.rawValue + 1)?.title ?? "")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.textLight)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.sunAmber)
                        .frame(width: geo.size.width * max(0, min(progress, 1)), height: 8)
                        .animation(.spring(duration: 0.6), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    private func levelRow(_ lvl: SunLevel) -> some View {
        let unlocked = vm.wakeStreak >= lvl.streakThreshold
        let isCurrent = vm.sunLevel == lvl
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(unlocked ? AppTheme.sunAmber : Color.gray.opacity(0.15))
                    .frame(width: 36, height: 36)
                if unlocked {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .font(.system(size: 14))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(lvl.title)
                        .font(.system(.subheadline, design: .rounded, weight: isCurrent ? .bold : .regular))
                        .foregroundStyle(unlocked ? AppTheme.textDark : AppTheme.textLight)
                    if isCurrent {
                        Text("YOU")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.sunAmber)
                            .clipShape(Capsule())
                    }
                }
                Text("\(lvl.streakThreshold)+ days")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(AppTheme.textLight)
            }
            Spacer()
        }
    }
}

// MARK: - Alarm Ringing Screen

private struct AlarmRingingScreen: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            AppTheme.alarmGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Time
                Text(Date.now.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            pulseScale = 1.06
                        }
                    }

                Text("Time to wake up!")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 6)

                Spacer()

                SunMascotView(level: vm.sunLevel, mood: .excited, size: 160)
                    .padding(.bottom, 8)

                Text("Get up and find Sunny to stop this!")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        vm.startNFCScanForDismissal()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "wave.3.right.circle.fill")
                                .font(.title3)
                            Text(vm.isNFCScanning ? "Scanning…" : "Find Sunny")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .white.opacity(0.22)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.5), lineWidth: 1.5)
                    )
                    .disabled(vm.isNFCScanning)

                    if let err = vm.nfcError {
                        Text(err)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }
}

// MARK: - Check-In Screen

private struct CheckInScreen: View {
    @EnvironmentObject private var vm: AlarmAppViewModel

    var body: some View {
        ZStack {
            AppTheme.successGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                SunMascotView(level: vm.sunLevel, mood: .happy, size: 150)
                    .padding(.bottom, 24)

                Text(vm.currentCheckInRound == 0 ? "Good tap!" : "Still standing?")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textDark)

                Text("Check-in \(vm.currentCheckInRound + 1) of \(vm.checkInRounds)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.textMedium)
                    .padding(.top, 6)

                Text("Confirm you're actually up and moving.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppTheme.textMedium)
                    .padding(.top, 14)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: 12) {
                    Button("Yes, I'm up!") {
                        vm.confirmAwake()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: AppTheme.textDark))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }
}

// MARK: - Level Up Screen

private struct LevelUpScreen: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppTheme.homeGradient(hour: AppTheme.currentHour).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                Text("Level Up!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textDark)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 4)

                Text(vm.sunLevel.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.sunAmber)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 30)

                SunMascotView(level: vm.sunLevel, mood: .celebrating, size: 180)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 20)

                Text(vm.sunLevel.subtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppTheme.textMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Button("Keep going!") { vm.dismissLevelUp() }
                    .buttonStyle(PrimaryButtonStyle(color: AppTheme.textDark))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.35)) {
                appeared = true
            }
        }
    }
}

// MARK: - Repeat Day Picker (shared)

struct RepeatDayPicker: View {
    @Binding var days: Set<RepeatDay>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RepeatDay.allCases) { day in
                let on = days.contains(day)
                Button(day.rawValue.prefix(1).uppercased() + day.rawValue.dropFirst().lowercased()) {
                    if on { days.remove(day) } else { days.insert(day) }
                }
                .font(.system(size: 12, weight: on ? .bold : .regular, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(on ? AppTheme.sunAmber : Color.gray.opacity(0.10))
                .foregroundStyle(on ? .white : AppTheme.textMedium)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .animation(.spring(duration: 0.2), value: on)
            }
        }
    }
}
