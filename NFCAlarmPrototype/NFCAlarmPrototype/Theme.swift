import SwiftUI

// MARK: - Color Palette

enum AppTheme {
    static let sunYellow    = Color(red: 1.00, green: 0.82, blue: 0.20)
    static let sunAmber     = Color(red: 1.00, green: 0.62, blue: 0.08)
    static let morningPeach = Color(red: 1.00, green: 0.88, blue: 0.70)
    static let deepNight    = Color(red: 0.10, green: 0.08, blue: 0.20)
    static let textDark     = Color(red: 0.12, green: 0.10, blue: 0.22)
    static let textMedium   = Color(red: 0.45, green: 0.42, blue: 0.55)
    static let textLight    = Color(red: 0.68, green: 0.65, blue: 0.74)
    static let bgCard       = Color.white

    // MARK: Time-adaptive home gradient
    static func homeGradient(hour: Int) -> LinearGradient {
        switch hour {
        case 5..<10:   // sunrise — soft pink-lavender to sky blue
            return LinearGradient(
                colors: [Color(red: 0.58, green: 0.62, blue: 0.92), Color(red: 0.78, green: 0.88, blue: 1.00)],
                startPoint: .top, endPoint: .bottom)
        case 10..<17:  // midday — clear sky blue
            return LinearGradient(
                colors: [Color(red: 0.24, green: 0.56, blue: 0.90), Color(red: 0.56, green: 0.82, blue: 1.00)],
                startPoint: .top, endPoint: .bottom)
        case 17..<21:  // sunset — deep indigo to soft periwinkle
            return LinearGradient(
                colors: [Color(red: 0.28, green: 0.22, blue: 0.62), Color(red: 0.55, green: 0.55, blue: 0.88)],
                startPoint: .top, endPoint: .bottom)
        default:       // night — deep navy to dark indigo
            return LinearGradient(
                colors: [Color(red: 0.06, green: 0.06, blue: 0.18), Color(red: 0.12, green: 0.10, blue: 0.28)],
                startPoint: .top, endPoint: .bottom)
        }
    }

    static let alarmGradient = LinearGradient(
        colors: [Color(red: 1.00, green: 0.40, blue: 0.20), Color(red: 1.00, green: 0.65, blue: 0.30)],
        startPoint: .top, endPoint: .bottom)

    static let successGradient = LinearGradient(
        colors: [Color(red: 0.88, green: 1.00, blue: 0.78), Color(red: 0.72, green: 0.98, blue: 0.60)],
        startPoint: .top, endPoint: .bottom)

    // MARK: Helpers
    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Up late?"
        }
    }

    static var currentHour: Int { Calendar.current.component(.hour, from: .now) }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = AppTheme.textDark

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(AppTheme.textDark)
            .background(AppTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.textDark.opacity(0.12), lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card container

struct SunCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}
