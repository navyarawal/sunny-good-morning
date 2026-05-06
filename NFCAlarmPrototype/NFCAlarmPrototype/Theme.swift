import SwiftUI

// MARK: - Color Palette

enum AppTheme {
    static let sunYellow    = Color(red: 1.00, green: 0.82, blue: 0.20)
    static let sunAmber     = Color(red: 0.98, green: 0.56, blue: 0.05)
    static let morningPeach = Color(red: 1.00, green: 0.86, blue: 0.68)
    static let sunriseBlue  = Color(red: 0.78, green: 0.89, blue: 0.96)
    static let cream        = Color(red: 1.00, green: 0.98, blue: 0.91)
    static let creamWarm    = Color(red: 1.00, green: 0.93, blue: 0.82)
    static let deepNight    = Color(red: 0.09, green: 0.08, blue: 0.19)
    static let textDark     = Color(red: 0.12, green: 0.10, blue: 0.22)
    static let textMedium   = Color(red: 0.45, green: 0.42, blue: 0.55)
    static let textLight    = Color(red: 0.68, green: 0.65, blue: 0.74)
    static let bgCard       = Color(red: 1.00, green: 0.99, blue: 0.94)

    // MARK: Time-adaptive home gradient
    static func homeGradient(hour: Int) -> LinearGradient {
        switch hour {
        case 5..<10:
            return LinearGradient(
                colors: [sunriseBlue, Color(red: 1.00, green: 0.88, blue: 0.70)],
                startPoint: .top, endPoint: .bottom)
        case 10..<17:
            return LinearGradient(
                colors: [Color(red: 0.72, green: 0.87, blue: 0.97), Color(red: 1.00, green: 0.90, blue: 0.72)],
                startPoint: .top, endPoint: .bottom)
        case 17..<21:
            return LinearGradient(
                colors: [Color(red: 0.63, green: 0.66, blue: 0.78), Color(red: 1.00, green: 0.74, blue: 0.55)],
                startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(
                colors: [Color(red: 0.42, green: 0.43, blue: 0.53), Color(red: 1.00, green: 0.78, blue: 0.60)],
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.textDark.opacity(0.10), lineWidth: 1.5))
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
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
