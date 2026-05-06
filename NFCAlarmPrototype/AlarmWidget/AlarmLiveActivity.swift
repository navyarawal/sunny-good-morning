import ActivityKit
import SwiftUI
import WidgetKit

struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.waves.left.and.right.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .font(.title3.bold())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("ALARM")
                        .font(.headline.bold())
                        .foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Tap to find Sunny")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .monospacedDigit()
                    .foregroundStyle(.red)
                    .frame(maxWidth: 50)
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(.red)
            }
            .keylineTint(.red)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.30, blue: 0.20),
                    Color(red: 1.00, green: 0.60, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("🚨 Alarm Ringing")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Tap your sticker to find Sunny")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }

                Spacer()

                Text(context.state.startedAt, style: .timer)
                    .monospacedDigit()
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 70)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }
}
