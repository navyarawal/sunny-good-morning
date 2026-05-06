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
            // 1. Soft outer halo
            if glow {
                Circle()
                    .fill(haloGradient)
                    .frame(width: size * 1.6, height: size * 1.6)
                    .blur(radius: 4)
                    .scaleEffect(pulse)
                    .opacity(0.85)
            }

            // 2. Rays (12 triangular spokes, gradient-filled, slowly rotating)
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    RaySpoke(size: size)
                        .fill(rayGradient)
                        .rotationEffect(.degrees(Double(i) * 30))
                        .shadow(color: Color(red: 0.78, green: 0.31, blue: 0.08).opacity(0.25), radius: 1.5, x: 0, y: 1)
                }
            }
            .rotationEffect(.degrees(rayRotation))

            // 3. Face (radial-gradient circle)
            Circle()
                .fill(faceGradient)
                .frame(width: size * 0.64, height: size * 0.64)
                .shadow(color: Color(red: 0.86, green: 0.47, blue: 0.16).opacity(0.30), radius: 8, x: 0, y: 6)

            // 4. Highlight on the face
            Ellipse()
                .fill(.white.opacity(0.45))
                .frame(width: size * 0.20, height: size * 0.12)
                .offset(x: -size * 0.10, y: -size * 0.12)

            // 5. Cheeks
            HStack(spacing: size * 0.18) {
                Circle().fill(Color(red: 1.0, green: 0.51, blue: 0.31).opacity(0.45))
                    .frame(width: size * 0.08, height: size * 0.08)
                Circle().fill(Color(red: 1.0, green: 0.51, blue: 0.31).opacity(0.45))
                    .frame(width: size * 0.08, height: size * 0.08)
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
                    style: StrokeStyle(lineWidth: size * 0.022, lineCap: .round)
                )
                .frame(width: size * 0.16, height: size * 0.08)
                .offset(y: size * 0.09)
        }
        .frame(width: size, height: size)
        .offset(y: bob)
        .onAppear { startAnimations() }
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
            Ellipse()
                .fill(Color(red: 0.227, green: 0.122, blue: 0.031))
                .frame(width: size * 0.036, height: size * 0.056)
        }
    }

    // MARK: - Gradients

    private var faceGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 1.00, green: 0.902, blue: 0.604),  // #FFE69A
                Color(red: 1.00, green: 0.761, blue: 0.278),  // #FFC247
                Color(red: 0.941, green: 0.541, blue: 0.118)  // #F08A1E
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
                Color(red: 1.0, green: 0.78, blue: 0.35).opacity(0.55),
                Color(red: 1.0, green: 0.67, blue: 0.31).opacity(0.25),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: size * 0.85
        )
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

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let inner = size * 0.30      // base of the triangle
        let outer = size * 0.46      // tip of the triangle
        let halfW = size * 0.045     // half-width of the base

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
