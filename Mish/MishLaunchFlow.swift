import SwiftUI

struct MishLaunchFlow: View {
    @EnvironmentObject private var player: PlayerModel
    @State private var introFinished = false

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.04)
                .ignoresSafeArea()

            if introFinished {
                ContentView()
                    .environmentObject(player)
                    .transition(.opacity)
            } else {
                MishLogoIntro {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        introFinished = true
                    }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct MishLogoIntro: View {
    let onFinished: () -> Void

    @State private var logoVisible = false
    @State private var detached = false
    @State private var orbitReady = false
    @State private var orbiting = false
    @State private var orbitProgress: CGFloat = 0
    @State private var returning = false

    var body: some View {
        GeometryReader { geometry in
            let fontSize = min(geometry.size.width * 0.25, 112)
            let dotSize = fontSize * 0.075
            let orbitRadius = fontSize * 1.12
            let centerShift = fontSize * 0.22

            ZStack {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("m")
                    ZStack {
                        // Dotless i: its dot is now a separate,
                        // animated circle instead of part of the glyph.
                        Text("ı")
                            .overlay(alignment: .top) {
                                Circle()
                                    .fill(Color.mishGreen)
                                    .frame(width: dotSize, height: dotSize)
                                    .offset(
                                        dotOffset(
                                            fontSize: fontSize,
                                            centerShift: centerShift,
                                            radius: orbitRadius
                                        )
                                    )
                                    .opacity(logoVisible ? 1 : 0)
                            }
                    }
                    Text("sh")
                }
                .font(.custom("delagothicone-regular", size: fontSize))
                .foregroundStyle(Color.mishGreen)
                .opacity(logoVisible ? 1 : 0)
                .scaleEffect(logoVisible ? 1 : 0.92)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                playIntro()
            }
        }
    }

    private func dotOffset(
        fontSize: CGFloat,
        centerShift: CGFloat,
        radius: CGFloat
    ) -> CGSize {
        // Return back onto top of the i
        if returning {
            return CGSize(width: 0, height: -fontSize * 0.38)
        }

        // Animated 360 orbit around wordmark
        if orbiting {
            let angle = -CGFloat.pi / 2 + (2 * CGFloat.pi * orbitProgress)
            return CGSize(
                width: centerShift + cos(angle) * radius,
                height: sin(angle) * radius
            )
        }

        // Ready position at top of orbit
        if orbitReady {
            return CGSize(width: centerShift, height: -radius)
        }

        // Detach upwards
        if detached {
            return CGSize(width: 0, height: -fontSize * 0.9)
        }

        // Default attached position
        return CGSize(width: 0, height: -fontSize * 0.38)
    }

    private func playIntro() {
        withAnimation(.easeOut(duration: 0.8)) {
            logoVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                detached = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                orbitReady = true
            }
        }

        // Trigger linear orbit cleanly from top to full circle (1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            orbiting = true
            withAnimation(.linear(duration: 2.2)) {
                orbitProgress = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                returning = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
            onFinished()
        }
    }
}
