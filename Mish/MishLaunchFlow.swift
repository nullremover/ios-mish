import SwiftUI

struct MishLaunchFlow: View {
    @EnvironmentObject private var player: PlayerModel
    @State private var introFinished = false
    @State private var orbitAmount: CGFloat = 0

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
    @State private var isOrbiting = false
    @State private var orbitAngle: CGFloat = -CGFloat.pi / 2
    @State private var returning = false

    var body: some View {
        GeometryReader { geometry in
            let fontSize = min(geometry.size.width * 0.25, 112)
            let dotSize = fontSize * 2
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
                                    .modifier(
                                        OrbitEffect(
                                            angle: orbitAngle,
                                            amount: orbitAmount,
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

   private func dotOffset(fontSize: CGFloat, centerShift: CGFloat, radius: CGFloat) -> CGSize {
    if returning {
        return CGSize(width: 0, height: -fontSize * 0.38)
    }
    if isOrbiting {
        return .zero                       // OrbitEffect handles the position
    }
    if orbitReady {
        return CGSize(width: centerShift, height: -radius)
    }
    if detached {
        return CGSize(width: 0, height: -fontSize * 0.9)
    }
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

        // Directly animate the angle through a full 360-degree rotation!
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Not animated: base offset goes (cs,-r) -> 0 while the effect
            // goes 0 -> (cs,-r), so the dot doesn't move at the handoff.
            isOrbiting = true
            orbitAmount = 1
        
            withAnimation(.linear(duration: 2.2)) {
                orbitAngle = -CGFloat.pi / 2 + (2 * CGFloat.pi)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                returning = true
                orbitAmount = 0     // fades the orbit offset out as the base offset returns to the i
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
            onFinished()
        }
    }
    
    private struct OrbitEffect: GeometryEffect {
    var angle: CGFloat
    var amount: CGFloat          // 1 = full orbit offset, 0 = none
    let centerShift: CGFloat
    let radius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(angle, amount) }
        set { angle = newValue.first; amount = newValue.second }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * (centerShift + cos(angle) * radius)
        let y = amount * (sin(angle) * radius)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}
}
