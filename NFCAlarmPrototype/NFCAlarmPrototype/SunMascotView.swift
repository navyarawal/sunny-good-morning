import SwiftUI

// MARK: - SunMascotView

struct SunMascotView: View {
    let level: SunLevel
    var mood: SunMood = .idle
    var size: CGFloat = 120

    @State private var rayRotation: Double = 0
    @State private var breatheScale: CGFloat = 1.0
    @State private var bounceY: CGFloat = 0

    var body: some View {
        ZStack {
            // Legendary outer glow
            if level == .legendary {
                Circle()
                    .fill(sunColor.opacity(0.18))
                    .frame(width: size * 1.85, height: size * 1.85)
                    .scaleEffect(breatheScale)
            }

            // Rays
            ZStack {
                let count = level.rayCount
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(sunColor.opacity(0.85))
                        .frame(width: size * 0.088, height: rayLength)
                        .offset(y: -(size * 0.6 + rayLength * 0.5))
                        .rotationEffect(.degrees(Double(i) * (360.0 / Double(count))))
                }
            }
            .rotationEffect(.degrees(rayRotation))

            // Sun body
            Circle()
                .fill(sunColor)
                .frame(width: size, height: size)
                .shadow(color: sunColor.opacity(0.50), radius: size * 0.14)
                .scaleEffect(breatheScale)

            // Face
            faceView
                .scaleEffect(breatheScale)

            // Accessories
            accessoriesView
        }
        .offset(y: bounceY)
        .onAppear { startIdleAnimations() }
        .onChange(of: mood) { _, newMood in handleMoodChange(newMood) }
    }

    // MARK: - Ray length per level

    private var rayLength: CGFloat {
        let factors: [CGFloat] = [0.18, 0.20, 0.22, 0.24, 0.26, 0.28, 0.32]
        return size * factors[level.rawValue]
    }

    // MARK: - Color per level

    private var sunColor: Color {
        let colors: [Color] = [
            Color(red: 1.00, green: 0.93, blue: 0.50),  // seedling:  pale yellow
            Color(red: 1.00, green: 0.88, blue: 0.28),  // rising:    warm yellow
            Color(red: 1.00, green: 0.82, blue: 0.18),  // shining:   bright yellow
            Color(red: 1.00, green: 0.75, blue: 0.12),  // glowing:   golden
            Color(red: 1.00, green: 0.67, blue: 0.08),  // radiant:   amber gold
            Color(red: 1.00, green: 0.57, blue: 0.04),  // blazing:   deep amber
            Color(red: 1.00, green: 0.48, blue: 0.00),  // legendary: pure amber-orange
        ]
        return colors[level.rawValue]
    }

    // MARK: - Face

    private var faceView: some View {
        VStack(spacing: size * 0.09) {
            eyesView
            mouthView
        }
        .offset(y: size * 0.05)
    }

    private var eyesView: some View {
        HStack(spacing: size * 0.22) {
            singleEye
            singleEye
        }
    }

    @ViewBuilder
    private var singleEye: some View {
        switch mood {
        case .excited, .celebrating:
            Ellipse()
                .fill(AppTheme.textDark)
                .frame(width: size * 0.10, height: size * 0.14)
        case .worried:
            RoundedRectangle(cornerRadius: 2)
                .fill(AppTheme.textDark)
                .frame(width: size * 0.12, height: size * 0.07)
        default:
            Circle()
                .fill(AppTheme.textDark)
                .frame(width: size * 0.10, height: size * 0.10)
        }
    }

    @ViewBuilder
    private var mouthView: some View {
        let w = size * 0.34
        let h = size * 0.18
        switch mood {
        case .idle:
            MouthShape(style: .gentle)
                .stroke(AppTheme.textDark, style: StrokeStyle(lineWidth: size * 0.042, lineCap: .round))
                .frame(width: w, height: h)
        case .happy, .celebrating:
            MouthShape(style: .big)
                .stroke(AppTheme.textDark, style: StrokeStyle(lineWidth: size * 0.042, lineCap: .round))
                .frame(width: w * 1.1, height: h)
        case .excited:
            MouthShape(style: .open)
                .stroke(AppTheme.textDark, style: StrokeStyle(lineWidth: size * 0.042, lineCap: .round))
                .frame(width: w * 1.1, height: h * 1.2)
        case .worried:
            MouthShape(style: .frown)
                .stroke(AppTheme.textDark, style: StrokeStyle(lineWidth: size * 0.042, lineCap: .round))
                .frame(width: w * 0.8, height: h * 0.8)
        }
    }

    // MARK: - Accessories

    @ViewBuilder
    private var accessoriesView: some View {
        switch level {
        case .seedling, .rising:
            EmptyView()
        case .shining:
            Text("✨")
                .font(.system(size: size * 0.22))
                .offset(x: size * 0.60, y: -size * 0.44)
        case .glowing:
            Text("🎩")
                .font(.system(size: size * 0.30))
                .offset(y: -(size * 0.74))
        case .radiant:
            ZStack {
                Text("🎩").font(.system(size: size * 0.30)).offset(y: -(size * 0.74))
                Text("🕶️").font(.system(size: size * 0.28)).offset(y: -size * 0.06)
            }
        case .blazing:
            ZStack {
                Text("👑").font(.system(size: size * 0.30)).offset(y: -(size * 0.76))
                Text("🕶️").font(.system(size: size * 0.28)).offset(y: -size * 0.06)
            }
        case .legendary:
            ZStack {
                Text("👑").font(.system(size: size * 0.30)).offset(y: -(size * 0.76))
                Text("🕶️").font(.system(size: size * 0.28)).offset(y: -size * 0.06)
                Text("⚡️").font(.system(size: size * 0.24)).offset(x: size * 0.62, y: size * 0.28)
            }
        }
    }

    // MARK: - Animations

    private func startIdleAnimations() {
        withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
            rayRotation = 360
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            breatheScale = 1.055
        }
        if mood == .excited || mood == .celebrating { startBounce() }
    }

    private func handleMoodChange(_ newMood: SunMood) {
        withAnimation(.spring(duration: 0.3)) {
            bounceY = 0
        }
        if newMood == .excited || newMood == .celebrating { startBounce() }
    }

    private func startBounce() {
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 9).repeatForever(autoreverses: true)) {
            bounceY = -9
        }
    }
}

// MARK: - MouthShape

struct MouthShape: Shape {
    enum Style { case gentle, big, open, frown }
    let style: Style

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        switch style {
        case .gentle:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: midX, y: rect.maxY))
        case .big:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3),
                control: CGPoint(x: midX, y: rect.maxY))
        case .open:
            // Wide open 'D' mouth — arc + chord
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: midX, y: rect.maxY * 1.2))
            path.closeSubpath()
        case .frown:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.2))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.2),
                control: CGPoint(x: midX, y: rect.minY))
        }
        return path
    }
}
