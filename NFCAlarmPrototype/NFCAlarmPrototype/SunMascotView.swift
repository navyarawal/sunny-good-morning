import SwiftUI

// MARK: - SunMascotView (Sunny — cartoon sun port from sunny-mascot.jsx)

struct SunMascotView: View {
    let level: SunLevel
    var mood: SunMood = .idle
    var size: CGFloat = 120
    var animated: Bool = true
    var glow: Bool = true

    @State private var rayRotation: Double = 0
    @State private var bob: CGFloat = 0
    @State private var pulse: CGFloat = 1.0

    // Map the existing SunMood enum onto the design's two variants.
    // happy/excited/celebrating → "happy" face, worried/sad → "sleepy"
    private var isSleepy: Bool {
        switch mood {
        case .worried: return true
        default:       return false
        }
    }

    var body: some View {
        ZStack {
            legendaryRainbowAura

            // 1. Soft outer halo
            if glow {
                Circle()
                    .fill(haloGradient)
                    .frame(width: size * haloScale, height: size * haloScale)
                    .blur(radius: 5 + CGFloat(level.rawValue) * 1.2)
                    .scaleEffect(pulse)
                    .opacity(0.78 + Double(level.rawValue) * 0.03)
            }

            orbitalShapes

            // 2. Rays grow denser and longer as the streak tier increases.
            ZStack {
                ForEach(0..<level.rayCount, id: \.self) { i in
                    RaySpoke(size: size, level: level)
                        .fill(rayGradient)
                        .rotationEffect(.degrees(Double(i) * (360.0 / Double(level.rayCount))))
                        .shadow(color: Color(red: 0.78, green: 0.31, blue: 0.08).opacity(0.25), radius: 1.5, x: 0, y: 1)
                }
            }
            .rotationEffect(.degrees(rayRotation))

            // 3. Face (radial-gradient circle)
            Circle()
                .fill(faceGradient)
                .frame(width: size * faceScale, height: size * faceScale)
                .overlay(faceRing)
                .shadow(color: Color(red: 0.86, green: 0.47, blue: 0.16).opacity(0.30), radius: 8 + CGFloat(level.rawValue) * 1.5, x: 0, y: 6)

            // 4. Highlight on the face
            Ellipse()
                .fill(.white.opacity(0.45))
                .frame(width: size * 0.20, height: size * 0.12)
                .offset(x: -size * 0.10, y: -size * 0.12)

            // 5. Cheeks
            HStack(spacing: size * 0.18) {
                Circle().fill(Color(red: 1.0, green: 0.51, blue: 0.31).opacity(0.45))
                    .frame(width: cheekSize, height: cheekSize)
                Circle().fill(Color(red: 1.0, green: 0.51, blue: 0.31).opacity(0.45))
                    .frame(width: cheekSize, height: cheekSize)
            }
            .offset(y: size * 0.05)

            // 6. Eyes
            HStack(spacing: size * 0.14) {
                eye
                eye
            }
            .offset(y: -size * 0.04)

            // 7. Smile
            SmileShape()
                .stroke(
                    Color(red: 0.227, green: 0.122, blue: 0.031),
                    style: StrokeStyle(lineWidth: mouthWidth, lineCap: .round)
                )
                .frame(width: size * (0.16 + CGFloat(level.rawValue) * 0.012), height: size * 0.08)
                .offset(y: size * 0.09)

            accessoryView
        }
        .frame(width: size, height: size)
        .offset(y: bob)
        .onAppear { startAnimations() }
    }

    private var faceScale: CGFloat {
        0.56 + CGFloat(level.rawValue) * 0.065
    }

    private var haloScale: CGFloat {
        1.45 + CGFloat(level.rawValue) * 0.14
    }

    private var cheekSize: CGFloat {
        size * (0.07 + CGFloat(level.rawValue) * 0.006)
    }

    private var mouthWidth: CGFloat {
        size * (0.020 + CGFloat(level.rawValue) * 0.0025)
    }

    @ViewBuilder
    private var eye: some View {
        if isSleepy {
            // sleepy = upward arc
            Path { p in
                p.move(to: .zero)
                p.addQuadCurve(to: CGPoint(x: size * 0.10, y: 0),
                               control: CGPoint(x: size * 0.05, y: -size * 0.03))
            }
            .stroke(Color(red: 0.227, green: 0.122, blue: 0.031),
                    style: StrokeStyle(lineWidth: size * 0.022, lineCap: .round))
            .frame(width: size * 0.10, height: size * 0.06)
        } else {
            switch level {
            case .seedling, .rising:
                Ellipse()
                    .fill(Color(red: 0.227, green: 0.122, blue: 0.031))
                    .frame(width: size * 0.036, height: size * 0.056)
            case .shining, .glowing:
                Ellipse()
                    .fill(Color(red: 0.227, green: 0.122, blue: 0.031))
                    .frame(width: size * 0.045, height: size * 0.066)
                    .overlay(
                        Circle().fill(.white.opacity(0.75))
                            .frame(width: size * 0.012, height: size * 0.012)
                            .offset(x: -size * 0.008, y: -size * 0.014)
                    )
            case .radiant, .blazing, .legendary:
                SparkleShape(points: 4)
                    .fill(Color(red: 0.227, green: 0.122, blue: 0.031))
                    .frame(width: size * 0.060, height: size * 0.060)
            }
        }
    }

    // MARK: - Gradients

    private var faceGradient: RadialGradient {
        let tierBoost = Double(level.rawValue) * 0.018
        return RadialGradient(
            colors: [
                Color(red: 1.00, green: 0.902, blue: 0.604),  // #FFE69A
                Color(red: 1.00, green: min(0.82, 0.761 + tierBoost), blue: 0.278),  // #FFC247
                Color(red: 0.941, green: min(0.66, 0.541 + tierBoost), blue: 0.118)  // #F08A1E
            ],
            center: UnitPoint(x: 0.35, y: 0.30),
            startRadius: 0,
            endRadius: size * 0.55
        )
    }

    private var rayGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.820, blue: 0.353),  // #FFD15A
                Color(red: 0.953, green: 0.576, blue: 0.137)  // #F39323
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var haloGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.78, blue: 0.35).opacity(0.46 + Double(level.rawValue) * 0.045),
                Color(red: 1.0, green: 0.67, blue: 0.31).opacity(0.22 + Double(level.rawValue) * 0.025),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: size * 0.85
        )
    }

    @ViewBuilder
    private var faceRing: some View {
        if level.rawValue >= SunLevel.glowing.rawValue {
            Circle()
                .strokeBorder(
                    level == .legendary
                    ? AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
                    : AnyShapeStyle(Color.white.opacity(0.38)),
                    lineWidth: size * 0.014
                )
        }
    }

    @ViewBuilder
    private var legendaryRainbowAura: some View {
        if level == .legendary {
            Circle()
                .stroke(
                    AngularGradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red], center: .center),
                    lineWidth: size * 0.035
                )
                .frame(width: size * 1.55, height: size * 1.55)
                .blur(radius: 3)
                .rotationEffect(.degrees(-rayRotation * 0.5))
                .opacity(0.85)
        }
    }

    @ViewBuilder
    private var orbitalShapes: some View {
        if level.rawValue >= SunLevel.glowing.rawValue {
            ZStack {
                ForEach(0..<(level == .legendary ? 10 : 6), id: \.self) { i in
                    let angle = Double(i) * (360.0 / Double(level == .legendary ? 10 : 6))
                    SparkleShape(points: level == .legendary ? 8 : 4)
                        .fill(orbitalFill(index: i))
                        .frame(width: orbitalSize(index: i), height: orbitalSize(index: i))
                        .offset(y: -size * (0.68 + CGFloat(level.rawValue) * 0.035))
                        .rotationEffect(.degrees(angle + rayRotation * 0.35))
                        .opacity(0.70)
                }
            }
        }
    }

    private func orbitalSize(index: Int) -> CGFloat {
        size * (0.035 + CGFloat((index % 3)) * 0.010 + CGFloat(level.rawValue) * 0.004)
    }

    private func orbitalFill(index: Int) -> AnyShapeStyle {
        if level == .legendary {
            let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple]
            return AnyShapeStyle(colors[index % colors.count].opacity(0.92))
        }
        return AnyShapeStyle(Color.white.opacity(0.82))
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch level {
        case .seedling:
            EmptyView()
        case .rising:
            sproutRays
        case .shining:
            sunglasses
        case .glowing:
            partyHat
        case .radiant:
            sunglasses
            flameCrest
        case .blazing:
            crown
            flameCrest
        case .legendary:
            crown
            rainbowCape
        }
    }

    private var sproutRays: some View {
        HStack(spacing: size * 0.08) {
            LeafShape()
                .fill(Color(red: 0.50, green: 0.78, blue: 0.24))
                .frame(width: size * 0.11, height: size * 0.18)
                .rotationEffect(.degrees(-28))
            LeafShape()
                .fill(Color(red: 0.64, green: 0.86, blue: 0.30))
                .frame(width: size * 0.10, height: size * 0.16)
                .rotationEffect(.degrees(24))
        }
        .offset(y: -size * 0.29)
    }

    private var sunglasses: some View {
        HStack(spacing: size * 0.05) {
            RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
                .fill(Color(red: 0.11, green: 0.08, blue: 0.07))
                .frame(width: size * 0.105, height: size * 0.06)
            RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
                .fill(Color(red: 0.11, green: 0.08, blue: 0.07))
                .frame(width: size * 0.105, height: size * 0.06)
        }
        .overlay(
            Capsule()
                .fill(Color(red: 0.11, green: 0.08, blue: 0.07))
                .frame(width: size * 0.05, height: size * 0.012)
        )
        .offset(y: -size * 0.045)
    }

    private var partyHat: some View {
        Triangle()
            .fill(LinearGradient(colors: [Color(red: 0.40, green: 0.71, blue: 1.0), Color(red: 0.93, green: 0.35, blue: 0.95)], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.20, height: size * 0.25)
            .overlay(
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.045, height: size * 0.045)
                    .offset(y: -size * 0.13)
            )
            .rotationEffect(.degrees(-12))
            .offset(x: size * 0.08, y: -size * 0.30)
    }

    private var crown: some View {
        CrownShape()
            .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.93, blue: 0.34), Color(red: 0.96, green: 0.58, blue: 0.05)], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.30, height: size * 0.18)
            .overlay(CrownShape().stroke(.white.opacity(0.65), lineWidth: 1))
            .rotationEffect(.degrees(-7))
            .offset(y: -size * 0.30)
    }

    private var flameCrest: some View {
        HStack(spacing: -size * 0.02) {
            ForEach(0..<3, id: \.self) { i in
                FlameShape()
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.94, blue: 0.32), Color(red: 1.0, green: 0.26, blue: 0.10)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * (0.11 + CGFloat(i == 1 ? 0.04 : 0)), height: size * (0.20 + CGFloat(i == 1 ? 0.06 : 0)))
            }
        }
        .offset(y: -size * 0.40)
    }

    private var rainbowCape: some View {
        Capsule()
            .fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
            .frame(width: size * 0.66, height: size * 0.16)
            .rotationEffect(.degrees(5))
            .offset(y: size * 0.32)
            .opacity(0.82)
    }

    // MARK: - Animation

    private func startAnimations() {
        guard animated else { return }
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
            rayRotation = 360
        }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            bob = -size * 0.025
        }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            pulse = 1.06
        }
    }
}

// MARK: - Ray spoke shape (triangle pointing up from inner radius to outer tip)

private struct RaySpoke: Shape {
    let size: CGFloat
    let level: SunLevel

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let raw = CGFloat(level.rawValue)
        let inner = size * (0.26 + raw * 0.012)
        let outer = size * (0.44 + raw * 0.040)
        let halfW = size * (0.040 + raw * 0.006)

        // Triangle pointing up (rotation handled by caller via .rotationEffect)
        var p = Path()
        p.move(to: CGPoint(x: cx - halfW, y: cy - inner))
        p.addLine(to: CGPoint(x: cx, y: cy - outer))
        p.addLine(to: CGPoint(x: cx + halfW, y: cy - inner))
        p.closeSubpath()
        return p
    }
}

// MARK: - Smile shape (Q-curve "U")

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.4)
        )
        return p
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SparkleShape: Shape {
    let points: Int

    func path(in rect: CGRect) -> Path {
        let count = max(4, points * 2)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) * 0.5
        let inner = outer * 0.42
        var path = Path()
        for i in 0..<count {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = Double(i) / Double(count) * .pi * 2 - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(Darwin.cos(angle)) * radius,
                y: center.y + CGFloat(Darwin.sin(angle)) * radius
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.midY))
        return path
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY * 0.78),
            control1: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.height * 0.20),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.52)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY * 0.78),
            control: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.52),
            control2: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.height * 0.20)
        )
        path.closeSubpath()
        return path
    }
}

private struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.90, y: rect.minY + rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Legacy MouthShape (kept for existing screens that reference it directly)

struct MouthShape: Shape {
    enum Style { case gentle, big, open, frown }
    let style: Style

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch style {
        case .gentle, .big, .open:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY * 1.4)
            )
        case .frown:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.minY * 0.4)
            )
        }
        return path
    }
}
