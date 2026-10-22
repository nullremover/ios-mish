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

    private let letters = ["m", "i", "s", "h"]

    @State private var landed = Array(repeating: false, count: 4)
    @State private var pulse = false
    @State private var glow = false
    @State private var showEcho1 = false
    @State private var showEcho2 = false
    @State private var shine: CGFloat = -0.4

    var body: some View {
        GeometryReader { geo in
            let fontSize = min(geo.size.width * 0.25, 112)

            ZStack {
                // Afterimage echoes (3DS-style)
                if showEcho2 {
                    EchoView(endScale: 1.8, startOpacity: 0.25, duration: 0.9) {
                        staticLogo(fontSize)
                    }
                }
                if showEcho1 {
                    EchoView(endScale: 1.4, startOpacity: 0.45, duration: 0.7) {
                        staticLogo(fontSize)
                    }
                }

                // Main logo: letters snap in one by one
                droppingLogo(fontSize)
                    .overlay { shineOverlay(fontSize) }
                    .shadow(
                        color: Color.mishGreen.opacity(glow ? 0.6 : 0),
                        radius: glow ? 24 : 0
                    )
                    .scaleEffect(pulse ? 1.07 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { playIntro() }
        }
    }

    // MARK: - Pieces

    private func staticLogo(_ fontSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(letters.indices, id: \.self) { i in
                Text(letters[i])
            }
        }
        .font(.custom("delagothicone-regular", size: fontSize))
        .foregroundStyle(Color.mishGreen)
    }

    private func droppingLogo(_ fontSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(letters.indices, id: \.self) { i in
                Text(letters[i])
                    .offset(y: landed[i] ? 0 : -fontSize * 1.4)
                    .rotationEffect(.degrees(landed[i] ? 0 : (i % 2 == 0 ? -14 : 14)))
                    .scaleEffect(landed[i] ? 1 : 1.25)
                    .opacity(landed[i] ? 1 : 0)
            }
        }
        .font(.custom("delagothicone-regular", size: fontSize))
        .foregroundStyle(Color.mishGreen)
    }

    private func shineOverlay(_ fontSize: CGFloat) -> some View {
        GeometryReader { g in
            LinearGradient(
                colors: [Color.clear, Color.white.opacity(0.85), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: g.size.width * 0.4)
            .offset(x: shine * g.size.width)
        }
        .mask(staticLogo(fontSize))
        .allowsHitTesting(false)
    }

    // MARK: - Timeline

    private func playIntro() {
        // Letters snap in, staggered
        for i in letters.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.12) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.58)) {
                    landed[i] = true
                }
            }
        }

        // Impact: pulse, glow, first echo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            showEcho1 = true
            withAnimation(.easeOut(duration: 0.08)) {
                pulse = true
                glow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    pulse = false
                }
                withAnimation(.easeOut(duration: 0.6)) {
                    glow = false
                }
            }
        }

        // Second, fainter echo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showEcho2 = true
        }

        // Shine sweep
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.7)) {
                shine = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            onFinished()
        }
    }
}

/// A ghost copy of the logo that expands and fades out as soon as it appears.
    private struct EchoView<Content: View>: View {
        let endScale: CGFloat
        let startOpacity: Double
        let duration: Double
        let content: Content
    
        @State private var go = false
    
        init(
            endScale: CGFloat,
            startOpacity: Double,
            duration: Double,
            @ViewBuilder content: () -> Content
        ) {
            self.endScale = endScale
            self.startOpacity = startOpacity
            self.duration = duration
            self.content = content()
        }
    
        var body: some View {
            content
                .opacity(go ? 0 : startOpacity)
                .scaleEffect(go ? endScale : 1)
                .onAppear {
                    withAnimation(.easeOut(duration: duration)) { go = true }
                }
        }
    }
