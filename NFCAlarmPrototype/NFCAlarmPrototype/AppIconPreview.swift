import SwiftUI

// MARK: - App Icon Options Preview
// Open this file in Xcode and use the canvas (⌘+Option+Return) to see all 4 options.
// Delete this file once you've picked one.

private let S: CGFloat = 160  // preview tile size

// MARK: Option 1 — Classic Sunny (warm gradient body, bold rays, rosy cheeks)

private struct Icon1: View {
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: S * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.87, blue: 0.58),
                            Color(red: 0.99, green: 0.72, blue: 0.32)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Rays
            let rayColor = Color(red: 0.96, green: 0.62, blue: 0.12)
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(rayColor)
                    .frame(width: S * 0.085, height: S * 0.20)
                    .offset(y: -(S * 0.365))
                    .rotationEffect(.degrees(Double(i) * 45))
            }

            // Face circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.97, blue: 0.70),
                            Color(red: 1.00, green: 0.88, blue: 0.34)
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 0, endRadius: S * 0.28
                    )
                )
                .frame(width: S * 0.60, height: S * 0.60)
                .shadow(color: Color(red: 0.86, green: 0.50, blue: 0.08).opacity(0.4), radius: 6, y: 4)

            // Eyes
            HStack(spacing: S * 0.12) {
                eyeDot; eyeDot
            }
            .offset(y: -S * 0.04)

            // Cheeks
            HStack(spacing: S * 0.22) {
                cheek; cheek
            }
            .offset(y: S * 0.07)

            // Smile
            MouthShape(style: .big)
                .stroke(Color(red: 0.30, green: 0.18, blue: 0.05),
                        style: StrokeStyle(lineWidth: S * 0.035, lineCap: .round))
                .frame(width: S * 0.26, height: S * 0.14)
                .offset(y: S * 0.08)
        }
        .frame(width: S, height: S)
        .clipShape(RoundedRectangle(cornerRadius: S * 0.22))
    }

    private var eyeDot: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.22, green: 0.14, blue: 0.04))
                .frame(width: S * 0.082, height: S * 0.082)
            Circle()
                .fill(.white.opacity(0.75))
                .frame(width: S * 0.026, height: S * 0.026)
                .offset(x: S * 0.018, y: -S * 0.018)
        }
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(red: 1.0, green: 0.55, blue: 0.50).opacity(0.42))
            .frame(width: S * 0.13, height: S * 0.075)
    }
}

// MARK: Option 2 — Minimal (white background, clean linework sun)

private struct Icon2: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: S * 0.22)
                .fill(Color(red: 1.00, green: 0.97, blue: 0.90))

            // Thin rays
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Color(red: 0.95, green: 0.72, blue: 0.20))
                    .frame(width: S * 0.048, height: S * 0.14)
                    .offset(y: -(S * 0.37))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // Solid yellow circle
            Circle()
                .fill(Color(red: 0.99, green: 0.82, blue: 0.22))
                .frame(width: S * 0.54, height: S * 0.54)

            // Simple dot eyes
            HStack(spacing: S * 0.11) {
                Circle().fill(Color(red: 0.20, green: 0.12, blue: 0.03))
                    .frame(width: S * 0.07, height: S * 0.07)
                Circle().fill(Color(red: 0.20, green: 0.12, blue: 0.03))
                    .frame(width: S * 0.07, height: S * 0.07)
            }
            .offset(y: -S * 0.04)

            // Small arc smile
            MouthShape(style: .gentle)
                .stroke(Color(red: 0.20, green: 0.12, blue: 0.03),
                        style: StrokeStyle(lineWidth: S * 0.03, lineCap: .round))
                .frame(width: S * 0.20, height: S * 0.10)
                .offset(y: S * 0.08)
        }
        .frame(width: S, height: S)
        .clipShape(RoundedRectangle(cornerRadius: S * 0.22))
    }
}

// MARK: Option 3 — Sunrise Scene (sky gradient, horizon, big sun rising)

private struct Icon3: View {
    var body: some View {
        ZStack {
            // Sky gradient
            RoundedRectangle(cornerRadius: S * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.58, blue: 0.26),
                            Color(red: 1.00, green: 0.82, blue: 0.46),
                            Color(red: 1.00, green: 0.95, blue: 0.72)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Horizon line
            Rectangle()
                .fill(Color(red: 0.96, green: 0.54, blue: 0.18).opacity(0.35))
                .frame(height: 1.5)
                .offset(y: S * 0.12)

            // Sun rays fanning up
            ForEach(0..<7, id: \.self) { i in
                let angle = Double(i - 3) * 18.0
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 1.0, green: 0.92, blue: 0.50).opacity(0.70))
                    .frame(width: S * 0.06, height: S * 0.22)
                    .offset(y: -(S * 0.26))
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .offset(y: S * 0.10)
            }

            // Sun semi-circle rising from horizon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.97, blue: 0.72),
                            Color(red: 1.00, green: 0.84, blue: 0.26)
                        ],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 0, endRadius: S * 0.22
                    )
                )
                .frame(width: S * 0.52, height: S * 0.52)
                .offset(y: S * 0.06)
                .shadow(color: Color(red: 0.95, green: 0.55, blue: 0.10).opacity(0.5), radius: 10, y: 0)

            // Face
            HStack(spacing: S * 0.11) {
                eyeDot; eyeDot
            }
            .offset(y: S * 0.03)

            MouthShape(style: .big)
                .stroke(Color(red: 0.28, green: 0.16, blue: 0.04),
                        style: StrokeStyle(lineWidth: S * 0.033, lineCap: .round))
                .frame(width: S * 0.22, height: S * 0.12)
                .offset(y: S * 0.12)
        }
        .frame(width: S, height: S)
        .clipShape(RoundedRectangle(cornerRadius: S * 0.22))
    }

    private var eyeDot: some View {
        ZStack {
            Circle().fill(Color(red: 0.22, green: 0.14, blue: 0.04))
                .frame(width: S * 0.075, height: S * 0.075)
            Circle().fill(.white.opacity(0.7))
                .frame(width: S * 0.024, height: S * 0.024)
                .offset(x: S * 0.016, y: -S * 0.016)
        }
    }
}

// MARK: Option 4 — Dark Mode / Night Owl (deep navy, glowing sun)

private struct Icon4: View {
    var body: some View {
        ZStack {
            // Deep navy background
            RoundedRectangle(cornerRadius: S * 0.22)
                .fill(Color(red: 0.09, green: 0.08, blue: 0.18))

            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.72, blue: 0.20).opacity(0.22),
                            .clear
                        ],
                        center: .center,
                        startRadius: S * 0.28, endRadius: S * 0.52
                    )
                )
                .frame(width: S, height: S)

            // Glowing rays
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.80, blue: 0.22).opacity(0.9),
                                Color(red: 1.00, green: 0.55, blue: 0.10).opacity(0.0)
                            ],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .frame(width: S * 0.07, height: S * 0.22)
                    .offset(y: -(S * 0.36))
                    .rotationEffect(.degrees(Double(i) * 45))
            }

            // Sun body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.96, blue: 0.68),
                            Color(red: 0.99, green: 0.76, blue: 0.22)
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 0, endRadius: S * 0.26
                    )
                )
                .frame(width: S * 0.55, height: S * 0.55)
                .shadow(color: Color(red: 1.00, green: 0.72, blue: 0.20).opacity(0.6), radius: 14)

            // Eyes
            HStack(spacing: S * 0.12) {
                eyeDot; eyeDot
            }
            .offset(y: -S * 0.04)

            // Cheeks
            HStack(spacing: S * 0.20) {
                cheek; cheek
            }
            .offset(y: S * 0.07)

            // Smile
            MouthShape(style: .big)
                .stroke(Color(red: 0.24, green: 0.14, blue: 0.04),
                        style: StrokeStyle(lineWidth: S * 0.034, lineCap: .round))
                .frame(width: S * 0.26, height: S * 0.13)
                .offset(y: S * 0.08)
        }
        .frame(width: S, height: S)
        .clipShape(RoundedRectangle(cornerRadius: S * 0.22))
    }

    private var eyeDot: some View {
        ZStack {
            Circle().fill(Color(red: 0.20, green: 0.12, blue: 0.04))
                .frame(width: S * 0.08, height: S * 0.08)
            Circle().fill(.white.opacity(0.75))
                .frame(width: S * 0.026, height: S * 0.026)
                .offset(x: S * 0.018, y: -S * 0.018)
        }
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(red: 1.0, green: 0.52, blue: 0.35).opacity(0.40))
            .frame(width: S * 0.13, height: S * 0.072)
    }
}

// MARK: - Preview

#Preview("App Icon Options") {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                Icon1()
                Text("1 · Classic Sunny").font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                Icon2()
                Text("2 · Minimal").font(.caption).foregroundStyle(.secondary)
            }
        }
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                Icon3()
                Text("3 · Sunrise Scene").font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                Icon4()
                Text("4 · Night Glow").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    .padding(32)
    .background(Color(uiColor: .systemGroupedBackground))
}
