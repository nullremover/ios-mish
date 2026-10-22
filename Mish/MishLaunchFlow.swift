
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
    @State private var dotDetached = false
    @State private var orbiting = false
    @State private var dotReturned = false

    var body: some View {
        GeometryReader { geometry in
            let logoWidth = min(geometry.size.width * 0.82, 420)

            ZStack {
                // The wordmark
                Text("mish")
                    .font(
                        .custom("delagothicone-regular", size: logoWidth * 0.24)
                    )
                    .foregroundStyle(Color.mishGreen)
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1 : 0.88)

                // The detached dot
                Circle()
                    .fill(Color.mishGreen)
                    .frame(width: logoWidth * 0.035)
                    .offset(
                        x: dotOffsetX,
                        y: dotOffsetY
                    )
                    .opacity(logoVisible ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                playIntro()
            }
        }
    }

    private var dotOffsetX: CGFloat {
        if !dotDetached {
            return 0
        }

        if orbiting {
            return cos(orbitAngle) * 75
        }

        return dotReturned ? 0 : 0
    }

    private var dotOffsetY: CGFloat {
        if !dotDetached {
            return -17
        }

        if orbiting {
            return sin(orbitAngle) * 75
        }

        return dotReturned ? -17 : -95
    }

    private var orbitAngle: CGFloat {
        CGFloat(Date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6))
            * (.pi / 3)
    }

    private func playIntro() {
        withAnimation(.easeOut(duration: 0.8)) {
            logoVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                dotDetached = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.linear(duration: 1.4)) {
                orbiting = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.9) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                orbiting = false
                dotReturned = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            onFinished()
        }
    }
}
