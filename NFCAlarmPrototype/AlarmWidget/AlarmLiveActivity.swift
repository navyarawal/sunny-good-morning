import ActivityKit
import SwiftUI
import WidgetKit

struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SunIcon(size: 36)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "wave.3.right")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.label.isEmpty ? "Rise & Tap!" : context.attributes.label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Tap your Sunny sticker to dismiss")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                SunIcon(size: 20)
            } compactTrailing: {
                Text("TAP")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            } minimal: {
                SunIcon(size: 16)
            }
        }
    }
}

// MARK: - Lock Screen banner

private struct LockScreenView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.87, blue: 0.45),
                    Color(red: 0.98, green: 0.62, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.95, blue: 0.70).opacity(0.55))
                        .frame(width: 64, height: 64)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.95, blue: 0.55),
                                    Color(red: 0.94, green: 0.55, blue: 0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(red: 0.85, green: 0.40, blue: 0.05).opacity(0.4), radius: 6)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.label.isEmpty ? "Good morning! ☀️" : context.attributes.label)
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.20, green: 0.09, blue: 0.01))

                    Text("Tap your Sunny sticker to dismiss")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.30, green: 0.14, blue: 0.02))
                }

                Spacer()

                Image(systemName: "hand.tap.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.22, green: 0.10, blue: 0.01).opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Reusable sun icon

private struct SunIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.93, blue: 0.60).opacity(0.4))
                .frame(width: size * 1.4, height: size * 1.4)
            Image(systemName: "sun.max.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.92, blue: 0.45), Color(red: 0.96, green: 0.58, blue: 0.13)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }
}
