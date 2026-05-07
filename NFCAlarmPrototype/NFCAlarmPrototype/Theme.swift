import SwiftUI

// MARK: - Design tokens (Sunny — sunrise gradient + Dawnfire/Zenith accents)

enum AppTheme {
    // Brand colors lifted from Sunny design tokens
    static let textDark    = Color(red: 0.227, green: 0.165, blue: 0.102)   // #3A2A1A
    static let textMedium  = Color.black.opacity(0.55)
    static let textLight   = Color.black.opacity(0.32)
    static let accent      = Color(red: 0.910, green: 0.525, blue: 0.122)   // #E8861F  Dawnfire
    static let accent2     = Color(red: 0.941, green: 0.725, blue: 0.118)   // #F0B91E  Zenith
    static let accentHi    = Color(red: 0.973, green: 0.635, blue: 0.243)   // #F8A23E  light Dawnfire
    static let accentLow   = Color(red: 0.780, green: 0.416, blue: 0.078)   // #C76A14  dark Dawnfire
    static let bgCard      = Color.white

    // Legacy aliases — keep so existing call sites still compile
    static let sunYellow   = accent2
    static let sunAmber    = accent
    static let morningPeach = Color(red: 1.00, green: 0.86, blue: 0.68)
    static let sunriseBlue  = Color(red: 0.78, green: 0.89, blue: 0.96)
    static let cream        = Color(red: 1.00, green: 0.98, blue: 0.91)
    static let creamWarm    = Color(red: 1.00, green: 0.93, blue: 0.82)
    static let deepNight    = Color(red: 0.09, green: 0.08, blue: 0.19)

    // MARK: Sunrise gradient

    static var sunriseBackground: LinearGradient {
        evolutionBackground(for: .seedling)
    }

    static func evolutionBackground(for level: SunLevel) -> LinearGradient {
        let stops: [Gradient.Stop]
        switch level {
        case .seedling:
            stops = [
                .init(color: Color(red: 1.00, green: 0.702, blue: 0.416), location: 0.00),
                .init(color: Color(red: 1.00, green: 0.878, blue: 0.541), location: 0.42),
                .init(color: Color(red: 0.530, green: 0.678, blue: 0.820), location: 0.78),
                .init(color: Color(red: 0.105, green: 0.165, blue: 0.325), location: 1.00)
            ]
        case .rising:
            stops = [
                .init(color: Color(red: 1.00, green: 0.584, blue: 0.322), location: 0.00),
                .init(color: Color(red: 1.00, green: 0.792, blue: 0.420), location: 0.34),
                .init(color: Color(red: 0.440, green: 0.586, blue: 0.786), location: 0.76),
                .init(color: Color(red: 0.070, green: 0.120, blue: 0.270), location: 1.00)
            ]
        case .shining:
            stops = [
                .init(color: Color(red: 1.00, green: 0.494, blue: 0.255), location: 0.00),
                .init(color: Color(red: 0.980, green: 0.802, blue: 0.274), location: 0.30),
                .init(color: Color(red: 0.380, green: 0.520, blue: 0.760), location: 0.70),
                .init(color: Color(red: 0.050, green: 0.092, blue: 0.240), location: 1.00)
            ]
        case .glowing:
            stops = [
                .init(color: Color(red: 1.00, green: 0.408, blue: 0.196), location: 0.00),
                .init(color: Color(red: 1.00, green: 0.690, blue: 0.220), location: 0.30),
                .init(color: Color(red: 0.300, green: 0.400, blue: 0.700), location: 0.68),
                .init(color: Color(red: 0.040, green: 0.064, blue: 0.200), location: 1.00)
            ]
        case .radiant:
            stops = [
                .init(color: Color(red: 1.00, green: 0.328, blue: 0.168), location: 0.00),
                .init(color: Color(red: 1.00, green: 0.604, blue: 0.160), location: 0.24),
                .init(color: Color(red: 0.236, green: 0.304, blue: 0.630), location: 0.62),
                .init(color: Color(red: 0.028, green: 0.038, blue: 0.150), location: 1.00)
            ]
        case .blazing:
            stops = [
                .init(color: Color(red: 1.00, green: 0.252, blue: 0.112), location: 0.00),
                .init(color: Color(red: 0.930, green: 0.380, blue: 0.120), location: 0.22),
                .init(color: Color(red: 0.170, green: 0.210, blue: 0.500), location: 0.58),
                .init(color: Color(red: 0.018, green: 0.020, blue: 0.100), location: 1.00)
            ]
        case .legendary:
            stops = [
                .init(color: Color(red: 1.00, green: 0.294, blue: 0.294), location: 0.00),
                .init(color: Color(red: 1.00, green: 0.792, blue: 0.254), location: 0.18),
                .init(color: Color(red: 0.275, green: 0.860, blue: 0.590), location: 0.42),
                .init(color: Color(red: 0.190, green: 0.480, blue: 1.000), location: 0.66),
                .init(color: Color(red: 0.420, green: 0.160, blue: 0.720), location: 0.84),
                .init(color: Color(red: 0.030, green: 0.020, blue: 0.130), location: 1.00)
            ]
        }
        return LinearGradient(
            stops: stops,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Layered radial aura that sits over the gradient (top-center sun glow)
    static var sunriseAura: RadialGradient {
        RadialGradient(
            colors: [Color(red: 1.0, green: 0.78, blue: 0.47).opacity(0.35), .clear],
            center: .top,
            startRadius: 10,
            endRadius: 420
        )
    }

    // Pill button gradient
    static var pillGradient: LinearGradient {
        LinearGradient(
            colors: [accentHi, accent, accentLow],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // Toggle / chip gradient (lighter than pill)
    static var chipGradient: LinearGradient {
        LinearGradient(
            colors: [accentHi, accent],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // Alarm-ringing screen — warm orange (kept matched to design accents)
    static let alarmGradient = LinearGradient(
        colors: [Color(red: 1.00, green: 0.40, blue: 0.20), Color(red: 1.00, green: 0.65, blue: 0.30)],
        startPoint: .top, endPoint: .bottom)

    static let successGradient = LinearGradient(
        colors: [Color(red: 0.88, green: 1.00, blue: 0.78), Color(red: 0.72, green: 0.98, blue: 0.60)],
        startPoint: .top, endPoint: .bottom)

    // Legacy: callers in existing screens — return the new sunrise gradient regardless of hour
    static func homeGradient(hour: Int) -> LinearGradient { sunriseBackground }

    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    static var currentHour: Int { Calendar.current.component(.hour, from: .now) }
}

// MARK: - Layout constants — keep top/bottom bars and CTAs aligned across every screen.
// Named `UI` instead of `Layout` because SwiftUI exports its own `Layout` protocol.

enum UI {
    /// Top inset below the safe area (status bar / Dynamic Island).
    /// Headers and page eyebrows sit here.
    static let topInset: CGFloat = 16

    /// Bottom inset above the safe area (home indicator).
    /// Primary CTAs and dot indicators sit here.
    static let bottomInset: CGFloat = 32

    /// Horizontal screen padding — same on every screen so cards/buttons line up.
    static let hPad: CGFloat = 24

    /// Reserved bottom space when the floating tab bar is visible.
    static let tabBarSpace: CGFloat = 110
}

// MARK: - Sunrise background view (gradient + aura)

struct SunriseBackground: View {
    @EnvironmentObject private var vm: AlarmAppViewModel

    var body: some View {
        ZStack {
            AppTheme.evolutionBackground(for: vm.sunLevel)
            AppTheme.sunriseAura

            if vm.sunLevel == .legendary {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.25, blue: 0.55).opacity(0.22),
                        Color(red: 0.30, green: 0.75, blue: 1.0).opacity(0.18),
                        Color(red: 0.96, green: 0.78, blue: 0.20).opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Frost card (translucent white over the sunrise gradient)

struct FrostCard<Content: View>: View {
    var corner: CGFloat = 22
    @ViewBuilder let content: Content

    var body: some View {
        content
            .foregroundStyle(AppTheme.textDark)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.white.opacity(0.45))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.55, green: 0.35, blue: 0.16).opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

// Legacy alias — old screens use SunCard with internal padding
struct SunCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        FrostCard { content.padding(16) }
    }
}

// MARK: - Pill button (primary orange / secondary frost)

struct PillButtonStyle: ButtonStyle {
    var primary: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(primary ? .white : AppTheme.textDark)
            .background(
                Group {
                    if primary {
                        AppTheme.pillGradient
                    } else {
                        Color.white.opacity(0.5)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    primary ? .clear : AppTheme.textDark.opacity(0.12),
                    lineWidth: 1
                )
            )
            .shadow(color: primary ? Color(red: 0.86, green: 0.43, blue: 0.12).opacity(0.32) : .clear,
                    radius: 8, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

// Legacy aliases — old code references PrimaryButtonStyle(color:) and SecondaryButtonStyle()
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = AppTheme.accent
    func makeBody(configuration: Configuration) -> some View {
        PillButtonStyle(primary: true).makeBody(configuration: configuration)
    }
}
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PillButtonStyle(primary: false).makeBody(configuration: configuration)
    }
}

// MARK: - Onboarding progress dots

struct OnboardingDots: View {
    let count: Int
    let active: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? AppTheme.accent : Color.black.opacity(0.18))
                    .frame(width: i == active ? 22 : 6, height: 6)
                    .animation(.spring(duration: 0.3), value: active)
            }
        }
    }
}

// MARK: - Sunny-style toggle (orange gradient on)

struct SunnyToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? AnyShapeStyle(AppTheme.chipGradient) : AnyShapeStyle(Color.gray.opacity(0.30)))
                    .frame(width: 51, height: 31)
                Circle()
                    .fill(.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }
}
