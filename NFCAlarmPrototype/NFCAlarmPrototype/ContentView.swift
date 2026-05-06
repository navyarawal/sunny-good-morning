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
                MainTabsView()
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

// MARK: - Onboarding (4 steps)

private enum OnboardStep: Int { case welcome, nfcIntro, createPrompt, createAlarm }

private struct OnboardingFlow: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var step: OnboardStep = .welcome

    var body: some View {
        ZStack {
            SunriseBackground()
            switch step {
            case .welcome:
                WelcomeStep { vm.requestPermissions(); step = .nfcIntro }
            case .nfcIntro:
                NFCIntroStep { step = .createPrompt }
            case .createPrompt:
                CreatePromptStep { step = .createAlarm }
            case .createAlarm:
                CreateAlarmFlow(
                    initialAlarm: vm.onboardingAlarm,
                    isOnboarding: true,
                    onCancel: { step = .createPrompt },
                    onSave: { alarm in
                        vm.onboardingAlarm = alarm
                        vm.finishSetup()
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
}

private struct WelcomeStep: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            SunMascotView(level: .seedling, mood: .happy, size: 180)
                .padding(.bottom, 48)

            VStack(spacing: 0) {
                Text("Welcome to")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(AppTheme.textDark)
                Text("Sunny.")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(AppTheme.pillGradient)
            }
            Text("We help you wake up on time.")
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.textMedium)
                .padding(.top, 14)

            Spacer()

            VStack(spacing: 18) {
                Button("Get started", action: onNext)
                    .buttonStyle(PillButtonStyle())
                OnboardingDots(count: 4, active: 0)
            }
            .padding(.horizontal, UI.hPad)
            .padding(.bottom, UI.bottomInset)
        }
    }
}

private struct NFCIntroStep: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            NFCBadge(size: 130)
                .padding(.bottom, 36)

            Text("Wake up in\none tap.")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textDark)
                .lineSpacing(2)

            Text("Stick a Sunny tag across the room.\nTap your phone to it to dismiss the alarm — no more snooze.")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textMedium)
                .padding(.top, 14)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 18) {
                Button("Continue", action: onNext)
                    .buttonStyle(PillButtonStyle())
                OnboardingDots(count: 4, active: 1)
            }
            .padding(.horizontal, UI.hPad)
            .padding(.bottom, UI.bottomInset)
        }
    }
}

private struct NFCBadge: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.914, blue: 0.627),
                            Color(red: 1.00, green: 0.761, blue: 0.278),
                            Color(red: 0.910, green: 0.525, blue: 0.122)
                        ],
                        center: UnitPoint(x: 0.5, y: 0.4),
                        startRadius: 0, endRadius: size * 0.7
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.86, green: 0.43, blue: 0.12).opacity(0.35), radius: 14, x: 0, y: 12)

            HStack(spacing: size * 0.04) {
                Circle().fill(.white).frame(width: size * 0.07, height: size * 0.07)
                ForEach(0..<3, id: \.self) { i in
                    Path { p in
                        p.move(to: .zero)
                        p.addQuadCurve(
                            to: CGPoint(x: 0, y: size * 0.30),
                            control: CGPoint(x: size * 0.10, y: size * 0.15)
                        )
                    }
                    .stroke(.white.opacity(1.0 - Double(i) * 0.25), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: size * 0.10, height: size * 0.30)
                }
            }
        }
    }
}

private struct CreatePromptStep: View {
    var onNext: () -> Void
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.882, blue: 0.588).opacity(0.9),
                                Color(red: 1.0, green: 0.706, blue: 0.353).opacity(0.4),
                                .clear
                            ],
                            center: UnitPoint(x: 0.5, y: 0.45),
                            startRadius: 0, endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(AppTheme.chipGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(red: 0.86, green: 0.43, blue: 0.12).opacity(0.40), radius: 14, x: 0, y: 12)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .scaleEffect(pulse)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                            pulse = 1.06
                        }
                    }
            }
            .padding(.bottom, 36)

            Text("Create your\nfirst alarm.")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textDark)
                .lineSpacing(2)

            Spacer()

            VStack(spacing: 18) {
                Button("Let's go", action: onNext)
                    .buttonStyle(PillButtonStyle())
                OnboardingDots(count: 4, active: 2)
            }
            .padding(.horizontal, UI.hPad)
            .padding(.bottom, UI.bottomInset)
        }
    }
}

// MARK: - Main tabs (custom floating tab bar)

private enum MainTab { case list, create, profile }

private struct MainTabsView: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var tab: MainTab = .list
    @State private var editingAlarm: AlarmItem?

    var body: some View {
        ZStack {
            SunriseBackground()

            Group {
                switch tab {
                case .list:
                    AlarmListScreen(onAdd: { tab = .create }, onEdit: { editingAlarm = $0 })
                case .create:
                    CreateAlarmFlow(
                        initialAlarm: AlarmItem(),
                        isOnboarding: false,
                        onCancel: { tab = .list },
                        onSave: { alarm in
                            vm.alarms.insert(alarm, at: 0)
                            vm.alarmManager.scheduleAlarm(alarm, activeAlarmsCount: max(1, vm.alarms.filter(\.isEnabled).count))
                            tab = .list
                        }
                    )
                case .profile:
                    ProfileScreen()
                }
            }

            VStack {
                Spacer()
                FloatingTabBar(active: tab) { tab = $0 }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }
        }
        .sheet(item: $editingAlarm) { alarm in
            CreateAlarmFlow(
                initialAlarm: alarm,
                isOnboarding: false,
                onCancel: { editingAlarm = nil },
                onSave: { updated in
                    vm.updateAlarm(updated)
                    editingAlarm = nil
                }
            )
        }
    }
}

private struct FloatingTabBar: View {
    let active: MainTab
    let onChange: (MainTab) -> Void

    var body: some View {
        HStack(spacing: 6) {
            tabButton(.list, label: "Alarms", icon: "alarm")
            createButton
            tabButton(.profile, label: "You", icon: "sun.max")
        }
        .padding(6)
        .frame(height: 72)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(.white.opacity(0.45)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1))
        )
        .shadow(color: Color(red: 0.55, green: 0.35, blue: 0.16).opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private func tabButton(_ which: MainTab, label: String, icon: String) -> some View {
        let isActive = active == which
        return Button { onChange(which) } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textMedium)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Capsule()
                    .fill(isActive ? .white.opacity(0.85) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var createButton: some View {
        Button { onChange(.create) } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Capsule().fill(AppTheme.chipGradient))
                .shadow(color: Color(red: 0.86, green: 0.43, blue: 0.12).opacity(0.30), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Alarm list

private struct AlarmListScreen: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    var onAdd: () -> Void
    var onEdit: (AlarmItem) -> Void

    private var nextAlarm: AlarmItem? {
        vm.alarms.first(where: \.isEnabled)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eyebrowText())
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.textMedium)
                        Text(headlineText())
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(AppTheme.textDark)
                    }
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.top, UI.topInset)
                .padding(.bottom, 6)

                if vm.alarms.isEmpty {
                    FrostCard(corner: 24) {
                        Text("No alarms yet. Tap **+** to set one.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textMedium)
                            .padding(36)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 6)
                } else {
                    VStack(spacing: 12) {
                        ForEach(vm.alarms) { alarm in
                            AlarmRow(alarm: alarm,
                                     onTap: { onEdit(alarm) },
                                     onToggle: { vm.toggleAlarm(alarm) },
                                     onDelete: { vm.deleteAlarm(alarm) })
                                .contextMenu {
                                    Button(role: .destructive) {
                                        vm.deleteAlarm(alarm)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                Color.clear.frame(height: UI.tabBarSpace)
            }
            .padding(.horizontal, UI.hPad)
        }
    }

    private func eyebrowText() -> String {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: .now) ?? .now
        return "Tomorrow · " + tomorrow.formatted(.dateTime.weekday(.abbreviated))
    }

    private func headlineText() -> String {
        let h = AppTheme.currentHour
        return (h < 6 || h >= 21) ? "Good night." : AppTheme.greeting(hour: h) + "."
    }

    private func nextAlarmCard(_ alarm: AlarmItem) -> some View {
        let nextDate = nextFire(for: alarm)
        let countdown = countdownText(to: nextDate)
        return HStack(spacing: 16) {
            ZStack {
                Circle().fill(.white.opacity(0.55)).frame(width: 44, height: 44)
                Image(systemName: "alarm")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textDark)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT ALARM · \(countdown)")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.textDark.opacity(0.7))
                let label = alarm.label.isEmpty ? "Alarm" : alarm.label
                Text("\(alarm.timeText) · \(label)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textDark)
            }
            Spacer()
        }
        .padding(.horizontal, 22).padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 1, green: 0.824, blue: 0.549).opacity(0.85),
                             Color(red: 1, green: 0.667, blue: 0.353).opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color(red: 0.86, green: 0.47, blue: 0.16).opacity(0.20), radius: 14, x: 0, y: 8)
    }

    private func nextFire(for alarm: AlarmItem) -> Date {
        let cal = Calendar.current
        let now = Date()
        let timeComps = cal.dateComponents([.hour, .minute], from: alarm.date)
        var dc = cal.dateComponents([.year, .month, .day], from: now)
        dc.hour = timeComps.hour; dc.minute = timeComps.minute; dc.second = 0
        let today = cal.date(from: dc) ?? now
        return today > now ? today : (cal.date(byAdding: .day, value: 1, to: today) ?? today)
    }

    private func countdownText(to date: Date) -> String {
        let interval = max(0, date.timeIntervalSinceNow)
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h == 0 { return "IN \(m)M" }
        return "IN \(h)H \(m)M"
    }
}

private struct AlarmRow: View {
    let alarm: AlarmItem
    let onTap: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        FrostCard(corner: 22) {
            HStack(spacing: 14) {
                Button(action: onTap) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(timePrimary)
                                    .font(.system(size: 36, weight: .light))
                                    .tracking(-1.0)
                                    .foregroundStyle(AppTheme.textDark)
                                Text(timeAmPm)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(AppTheme.textMedium)
                            }
                            HStack(spacing: 8) {
                                if !alarm.label.isEmpty {
                                    Text(alarm.label)
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textMedium)
                                    Text("·").foregroundStyle(AppTheme.textLight)
                                }
                                HStack(spacing: 3) {
                                    ForEach(weekdayLetters.indices, id: \.self) { i in
                                        Text(weekdayLetters[i])
                                            .font(.system(size: 11, weight: .semibold))
                                            .frame(width: 16)
                                            .foregroundStyle(weekdayActive[i] ? AppTheme.accent : AppTheme.textDark.opacity(0.25))
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(alarm.isEnabled ? 1 : 0.55)

                SunnyToggle(isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { _ in onToggle() }
                ))

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.72))
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete alarm")
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
    }

    private var weekdayLetters: [String] { ["M", "T", "W", "T", "F", "S", "S"] }
    private var weekdayActive: [Bool] {
        let order: [RepeatDay] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
        return order.map { alarm.repeatDays.contains($0) }
    }

    private var timeFormatted: (String, String) {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let str = f.string(from: alarm.date)
        let parts = str.split(separator: " ")
        return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
    }
    private var timePrimary: String { timeFormatted.0 }
    private var timeAmPm: String { timeFormatted.1 }
}

// MARK: - Create Alarm flow (3 steps)

private struct CreateAlarmFlow: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    let isOnboarding: Bool
    let onCancel: () -> Void
    let onSave: (AlarmItem) -> Void

    @State private var alarm: AlarmItem
    @State private var step: Int = 1
    @State private var repeatExpanded = false
    @State private var soundExpanded = false

    init(initialAlarm: AlarmItem, isOnboarding: Bool, onCancel: @escaping () -> Void, onSave: @escaping (AlarmItem) -> Void) {
        self._alarm = State(initialValue: initialAlarm)
        self.isOnboarding = isOnboarding
        self.onCancel = onCancel
        self.onSave = onSave
    }

    private let weekdayOrder: [RepeatDay] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
    private let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        // Single root VStack — predictable top-down layout.
        // Each step VStack claims .infinity height and lays out header/scroll/buttons explicitly.
        VStack(spacing: 0) {
            switch step {
            case 1: detailsStep
            case 2: checkInStep
            default: nfcPlacementStep
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SunriseBackground())
        .overlay(alignment: .topLeading) {
            Text("v6")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(red: 1.0, green: 0.0, blue: 0.5)))
                .padding(.leading, 4)
                .padding(.top, 2)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: Step 1 — details (sticky header + scrollable body)

    private var detailsStep: some View {
        VStack(spacing: 0) {
            // HEADER — pinned at top
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                Text("Add Alarm")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textDark)
                Spacer()
                Button("Save") { step = 2 }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.top, UI.topInset)
            .padding(.horizontal, UI.hPad)
            .padding(.bottom, 12)

            // MIDDLE — greedy ScrollView
            ScrollView {
                VStack(spacing: 20) {
                    DatePicker("", selection: $alarm.date, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 200)

                    VStack(spacing: 0) {
                        repeatRow
                        Divider().background(AppTheme.textDark.opacity(0.10)).padding(.leading, 18)
                        labelRow
                        Divider().background(AppTheme.textDark.opacity(0.10)).padding(.leading, 18)
                        soundRow
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.45)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.65), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 0.55, green: 0.35, blue: 0.16).opacity(0.08), radius: 12, x: 0, y: 6)

                    Spacer(minLength: UI.bottomInset)
                }
                .padding(.horizontal, UI.hPad)
                .padding(.top, 8)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var repeatRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { repeatExpanded.toggle() }
            } label: {
                HStack {
                    Text("Repeat").font(.system(size: 16, weight: .medium)).foregroundStyle(AppTheme.textDark)
                    Spacer()
                    Text(repeatSummary).font(.system(size: 16)).foregroundStyle(AppTheme.textMedium)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textMedium)
                        .rotationEffect(.degrees(repeatExpanded ? 90 : 0))
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if repeatExpanded {
                HStack(spacing: 6) {
                    ForEach(weekdayOrder.indices, id: \.self) { i in
                        let day = weekdayOrder[i]
                        let on = alarm.repeatDays.contains(day)
                        Button {
                            if on { alarm.repeatDays.remove(day) } else { alarm.repeatDays.insert(day) }
                        } label: {
                            Text(weekdayLetters[i])
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .foregroundStyle(on ? .white : AppTheme.textDark)
                                .background(
                                    Capsule().fill(on ? AnyShapeStyle(AppTheme.chipGradient) : AnyShapeStyle(.white.opacity(0.6)))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 14)
            }
        }
    }

    private var labelRow: some View {
        HStack {
            Text("Label").font(.system(size: 16, weight: .medium)).foregroundStyle(AppTheme.textDark)
            Spacer()
            TextField("Sunrise", text: $alarm.label)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textDark)
                .frame(maxWidth: 180)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    private var soundRow: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { soundExpanded.toggle() }
            } label: {
                HStack {
                    Text("Sound").font(.system(size: 16, weight: .medium)).foregroundStyle(AppTheme.textDark)
                    Spacer()
                    Text(alarm.ringtoneName).font(.system(size: 16)).foregroundStyle(AppTheme.textMedium)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textMedium)
                        .rotationEffect(.degrees(soundExpanded ? 90 : 0))
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if soundExpanded {
                FlowingChips(items: AlarmManager.ringtoneNames, selected: alarm.ringtoneName) { name in
                    alarm.ringtoneName = name
                    vm.alarmManager.previewSound(volume: alarm.volume, ringtone: name)
                }
                .padding(.horizontal, 18).padding(.bottom, 14)
            }
        }
    }

    private var repeatSummary: String {
        let days = alarm.repeatDays
        if days.isEmpty { return "Never" }
        if days.count == 7 { return "Every day" }
        if days == [.mon, .tue, .wed, .thu, .fri] { return "Weekdays" }
        if days == [.sat, .sun] { return "Weekends" }
        return weekdayOrder.compactMap { days.contains($0) ? $0.rawValue : nil }.joined(separator: ", ")
    }

    // MARK: Step 2 — check-ins

    private var checkInStep: some View {
        VStack(spacing: 0) {
            // HEADER
            stepHeader(label: "STEP 2 OF 3", trailing: nil) { step = 1 }

            // MIDDLE — greedy ScrollView
            ScrollView {
                VStack(spacing: 0) {
                    SunMascotView(level: .seedling, mood: .happy, size: 96)
                        .padding(.top, 18)

                    Text("Want wake-up\ncheck-ins?")
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.textDark)
                        .padding(.top, 18)
                        .lineSpacing(2)

                    Text("The alarm can ring a few more times after you dismiss — to make sure you're really up.")
                        .font(.system(size: 14.5))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.textMedium)
                        .padding(.top, 10)
                        .padding(.horizontal, 36)

                    FrostCard(corner: 22) {
                        VStack(spacing: 0) {
                            StepperRow(
                                label: "Number of check-ins",
                                value: alarm.checkInRounds,
                                suffix: alarm.checkInRounds == 1 ? "check-in" : "check-ins",
                                range: 1...6,
                                onChange: { alarm.checkInRounds = $0 }
                            )
                            Divider().background(AppTheme.textDark.opacity(0.08)).padding(.vertical, 14)
                            StepperRow(
                                label: "Every",
                                value: alarm.checkInIntervalMinutes,
                                suffix: "minutes",
                                range: 1...30,
                                onChange: { alarm.checkInIntervalMinutes = $0 }
                            )
                        }
                        .padding(18)
                    }
                    .padding(.top, 18).padding(.horizontal, UI.hPad)

                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            // BOTTOM
            HStack(spacing: 10) {
                Button("Skip") { step = 3 }
                    .buttonStyle(PillButtonStyle(primary: false))
                Button("Add check-ins") { step = 3 }
                    .buttonStyle(PillButtonStyle(primary: true))
            }
            .padding(.horizontal, UI.hPad).padding(.bottom, UI.bottomInset).padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Shared header used by steps 2 & 3 — guarantees identical Y position.
    private func stepHeader(label: String, trailing: String?, onBack: @escaping () -> Void) -> some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textMedium)
            }
            Spacer()
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.textMedium)
            Spacer()
            if let trailing {
                Button(trailing) { onSave(alarm) }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            } else {
                Color.clear.frame(width: 60)
            }
        }
        .padding(.top, UI.topInset)
        .padding(.horizontal, UI.hPad)
        .padding(.bottom, 12)
    }

    // MARK: Step 3 — NFC placement

    private var nfcPlacementStep: some View {
        VStack(spacing: 0) {
            // HEADER
            stepHeader(label: "STEP 3 OF 3", trailing: "Skip") { step = 2 }

            // MIDDLE
            ScrollView {
                VStack(spacing: 22) {
                    NFCBadge(size: 130).padding(.top, 12)

                    Text("Place your\nSunny sticker.")
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.textDark)
                        .lineSpacing(2)

                    Text("Stick it across the room — somewhere you have to **get out of bed** to reach.")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.textMedium)
                        .padding(.horizontal, 32)

                    VStack(spacing: 8) {
                        placementTip(num: 1, title: "Far from your bed", subtitle: "At least a few steps away.")
                        placementTip(num: 2, title: "Eye level or lower", subtitle: "Easy to tap with your phone.")
                        placementTip(num: 3, title: "Smooth, flat surface", subtitle: "Avoid metal — it weakens the signal.")
                    }
                    .padding(.horizontal, UI.hPad)
                }
            }
            .frame(maxHeight: .infinity)

            // BOTTOM
            Button(actionTitle) {
                if vm.registeredStickerID == nil {
                    vm.startNFCRegistration { onSave(alarm) }
                } else {
                    onSave(alarm)
                }
            }
            .buttonStyle(PillButtonStyle(primary: true))
            .disabled(vm.isNFCScanning)
            .padding(.horizontal, UI.hPad).padding(.bottom, UI.bottomInset).padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionTitle: String {
        if vm.isNFCScanning { return "Scanning…" }
        if vm.registeredStickerID == nil { return "Pair sticker" }
        return "I've placed it"
    }

    private func placementTip(num: Int, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(AppTheme.chipGradient)
                .frame(width: 22, height: 22)
                .overlay(Text("\(num)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.textDark)
                Text(subtitle).font(.system(size: 12.5)).foregroundStyle(AppTheme.textMedium)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 1))
        )
    }
}

// MARK: - Profile

private struct ProfileScreen: View {
    @EnvironmentObject private var vm: AlarmAppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: UI.topInset)

                VStack(spacing: 18) {
                    SunMascotView(level: vm.sunLevel, mood: .happy, size: 170)

                    Text("GOOD MORNING.")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(AppTheme.textMedium)

                    Text("\(vm.wakeStreak)-day streak")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.textDark)
                }

                tierCard.padding(.horizontal, UI.hPad).padding(.top, 22)

                growthLadder.padding(.top, 22)

                statsGrid.padding(.horizontal, UI.hPad).padding(.top, 22)

                Spacer().frame(height: UI.tabBarSpace)
            }
        }
    }

    private var tierCard: some View {
        let level = vm.sunLevel
        let next = SunLevel(rawValue: level.rawValue + 1)
        let daysToNext = max(0, (next?.streakThreshold ?? level.streakThreshold) - vm.wakeStreak)
        let progress: Double = {
            guard let next else { return 1.0 }
            let span = Double(next.streakThreshold - level.streakThreshold)
            guard span > 0 else { return 1.0 }
            return min(1, max(0, Double(vm.wakeStreak - level.streakThreshold) / span))
        }()

        return VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT STATE")
                        .font(.system(size: 11, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(AppTheme.textDark.opacity(0.65))
                    Text(level.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.textDark)
                }
                Spacer()
                if let next {
                    VStack(alignment: .trailing, spacing: 1) {
                        (Text("Next: ").font(.system(size: 13)).foregroundStyle(AppTheme.textDark.opacity(0.7)) +
                         Text(next.title).font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.textDark))
                        Text("in \(daysToNext) days")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textDark.opacity(0.7))
                    }
                } else {
                    Text("Max tier!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textDark)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.45)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 1, green: 0.82, blue: 0.35), AppTheme.accent],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * progress), height: 8)
                        .shadow(color: Color(red: 1, green: 0.78, blue: 0.31).opacity(0.7), radius: 6, x: 0, y: 0)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 1, green: 0.824, blue: 0.549).opacity(0.85),
                             Color(red: 1, green: 0.667, blue: 0.353).opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color(red: 0.86, green: 0.47, blue: 0.16).opacity(0.20), radius: 14, x: 0, y: 8)
    }

    private var growthLadder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GROWTH")
                .font(.system(size: 11, weight: .semibold)).tracking(1.2)
                .foregroundStyle(AppTheme.textMedium)
                .padding(.leading, 26)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SunLevel.allCases, id: \.rawValue) { tier in
                        tierCell(tier)
                    }
                }
                .padding(.horizontal, UI.hPad)
            }
        }
    }

    private func tierCell(_ tier: SunLevel) -> some View {
        let reached = vm.wakeStreak >= tier.streakThreshold
        let isCurrent = vm.sunLevel == tier
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(reached
                        ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.91, blue: 0.63),
                                                                 Color(red: 1, green: 0.76, blue: 0.28)],
                                                       startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.black.opacity(0.15)))
                    .frame(width: 36, height: 36)
                Image(systemName: reached ? "sun.max.fill" : "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(reached ? .white : AppTheme.textDark.opacity(0.4))
            }
            Text(tier.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textDark)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(tier.streakThreshold)+ days")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textMedium)
        }
        .frame(width: 90)
        .padding(.vertical, 12).padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isCurrent
                      ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.91, blue: 0.63),
                                                              Color(red: 1, green: 0.76, blue: 0.28)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color.white.opacity(reached ? 0.7 : 0.4)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isCurrent ? AppTheme.accent.opacity(0.6) : .white.opacity(0.7),
                              lineWidth: isCurrent ? 1.5 : 1)
        )
        .opacity(reached ? 1 : 0.65)
    }

    private var statsGrid: some View {
        let stats: [(String, String)] = [
            ("ON TIME", "—"),
            ("BEST STREAK", "\(vm.wakeStreak) days"),
            ("AVG. WAKE", "—"),
            ("SUNNY TAPS", "\(vm.wakeStreak)")
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(stats, id: \.0) { stat in
                FrostCard(corner: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.0)
                            .font(.system(size: 11, weight: .semibold)).tracking(1.0)
                            .foregroundStyle(AppTheme.textMedium)
                        Text(stat.1)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.textDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
        }
    }
}

// MARK: - Alarm ringing / Check-in / Level up screens (restyled)

private struct AlarmRingingScreen: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            AppTheme.alarmGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Text(Date.now.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            pulseScale = 1.06
                        }
                    }
                Text("Time to wake up!")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 6)

                Spacer()

                SunMascotView(level: vm.sunLevel, mood: .happy, size: 160)

                Text("Get up and find Sunny.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 12)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        vm.startNFCScanForDismissal()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "wave.3.right.circle.fill").font(.system(size: 22))
                            Text(vm.isNFCScanning ? "Scanning…" : "Find Sunny")
                        }
                    }
                    .buttonStyle(PillButtonStyle(primary: false))
                    .disabled(vm.isNFCScanning)

                    if let err = vm.nfcError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, UI.hPad).padding(.bottom, UI.bottomInset)
            }
        }
    }
}

private struct CheckInScreen: View {
    @EnvironmentObject private var vm: AlarmAppViewModel

    var body: some View {
        ZStack {
            AppTheme.successGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                SunMascotView(level: vm.sunLevel, mood: .happy, size: 150)
                Text(vm.currentCheckInRound == 0 ? "Good tap!" : "Still standing?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.textDark)
                    .padding(.top, 24)

                Text("Check-in \(vm.currentCheckInRound + 1) of \(vm.checkInRounds)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textMedium)
                    .padding(.top, 6)

                Text("Confirm you're actually up and moving.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textMedium)
                    .padding(.top, 14)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)

                Spacer()

                Button("Yes, I'm up!") { vm.confirmAwake() }
                    .buttonStyle(PillButtonStyle(primary: true))
                    .padding(.horizontal, UI.hPad).padding(.bottom, UI.bottomInset)
            }
        }
    }
}

private struct LevelUpScreen: View {
    @EnvironmentObject private var vm: AlarmAppViewModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            SunriseBackground()
            VStack(spacing: 0) {
                Spacer()
                Text("Level Up!")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(AppTheme.textDark)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Text(vm.sunLevel.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 30)

                SunMascotView(level: vm.sunLevel, mood: .happy, size: 180)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 20)

                Text(vm.sunLevel.subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Button("Keep going!") { vm.dismissLevelUp() }
                    .buttonStyle(PillButtonStyle(primary: true))
                    .padding(.horizontal, UI.hPad).padding(.bottom, UI.bottomInset)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.35)) { appeared = true }
        }
    }
}

// MARK: - Helpers

private struct StepperRow: View {
    let label: String
    let value: Int
    let suffix: String
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold)).tracking(1.0)
                    .foregroundStyle(AppTheme.textMedium)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(value)")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.textDark)
                    Text(suffix)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMedium)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                stepButton("minus") { if value > range.lowerBound { onChange(value - 1) } }
                stepButton("plus")  { if value < range.upperBound { onChange(value + 1) } }
            }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(AppTheme.textDark)
                .background(Circle().fill(.white.opacity(0.7)))
                .overlay(Circle().strokeBorder(AppTheme.textDark.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct FlowingChips: View {
    let items: [String]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                let on = item == selected
                Button { onSelect(item) } label: {
                    Text(item)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .foregroundStyle(on ? .white : AppTheme.textDark)
                        .background(
                            Capsule().fill(on ? AnyShapeStyle(AppTheme.chipGradient) : AnyShapeStyle(.white.opacity(0.6)))
                        )
                        .overlay(Capsule().strokeBorder(on ? .clear : AppTheme.textDark.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
