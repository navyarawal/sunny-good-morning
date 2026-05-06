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
        LinearGradient(
            stops: [
                .init(color: Color(red: 1.00, green: 0.702, blue: 0.416), location: 0.00),  // #FFB36A
                .init(color: Color(red: 1.00, green: 0.788, blue: 0.478), location: 0.18),  // #FFC97A
                .init(color: Color(red: 1.00, green: 0.878, blue: 0.541), location: 0.38),  // #FFE08A
                .init(color: Color(red: 0.988, green: 0.929, blue: 0.690), location: 0.55), // #FCEDB0
                .init(color: Color(red: 0.863, green: 0.910, blue: 0.910), location: 0.75), // #DCE8E8
                .init(color: Color(red: 0.718, green: 0.808, blue: 0.878), location: 1.00)  // #B7CEE0
            ],
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
    var body: some View {
        ZStack {
            AppTheme.sunriseBackground
            AppTheme.sunriseAura
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
