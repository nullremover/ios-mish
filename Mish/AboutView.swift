import SwiftUI
import UIKit

struct SupporterItem: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 12))
                .italic()
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
}

struct AboutView: View {
    // Hardcoded version and build number as requested
    private let version = "0.2.8alpha"
    private let buildNumber = "145"

    @State private var taps = 0
    @State private var secret = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: 0x080809)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Close button
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 10)

                    Spacer().frame(height: 20)

                    // Mish Logo with Tap Secret (7 taps)
                    Text("mish")
                        .font(.custom("delagothicone-regular", size: 72))
                        .foregroundColor(.mishGreen)
                        .shadow(color: secret ? .mishGreen.opacity(0.7) : .clear, radius: secret ? 24 : 0)
                        .scaleEffect(secret ? 1.08 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.5), value: secret)
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            taps += 1
                            if taps >= 7 && !secret {
                                let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
                                heavyGenerator.impactOccurred()
                                
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    secret = true
                                }
                                triggerConfetti()
                            }
                        }

                    Spacer().frame(height: 10)

                    Text("Version \(version) • Build \(buildNumber)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))

                    Spacer().frame(height: 24)

                    Text("made with love by josh :3")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // Secret Supporters Section
                    if secret {
                        VStack(spacing: 16) {
                            Text("you found it ♥")
                                .font(.system(size: 15))
                                .foregroundColor(.mishGreen)

                            Spacer().frame(height: 8)

                            Text("SUPPORTERS")
                                .font(.system(size: 14, weight: .bold))
                                .underline()
                                .foregroundColor(.white)
                                .tracking(1.1)

                            VStack(spacing: 12) {
                                SupporterItem(
                                    title: "first android tester: sunscores/@lateforthetrain_",
                                    subtitle: "\"thank you for the healings healings 💝\""
                                )

                                SupporterItem(
                                    title: "first partial iOS tester: Supa Sweeter/@superman776",
                                    subtitle: "\"ur da goat. thx u\""
                                )

                                SupporterItem(
                                    title: "first windows tester/everything tester: professorevilscores/@reemran",
                                    subtitle: "\"THANK YOU FOR TRYING THE MORE BAREBONES VERSIONNN lol(but seriously ur the coolest)\""
                                )
                            }

                            Text("to anyone who wants credits text me :P")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.54))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }

            // Confetti Overlay
            ConfettiView()
        }
    }

    private func triggerConfetti() {
        NotificationCenter.default.post(name: NSNotification.Name("TriggerConfetti"), object: nil)
    }
}

// MARK: - Native UIKit Confetti Burst
struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TriggerConfetti"),
            object: nil,
            queue: .main
        ) { _ in
            let emitter = CAEmitterLayer()
            emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: -10)
            emitter.emitterShape = .line
            emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)

            let colors: [UIColor] = [
                UIColor(Color.mishGreen),
                .white,
                .systemPink,
                .systemPurple
            ]

            var cells: [CAEmitterCell] = []
            for color in colors {
                let cell = CAEmitterCell()
                cell.birthRate = 12
                cell.lifetime = 3.5
                cell.velocity = 200
                cell.velocityRange = 50
                cell.emissionLongitude = .pi
                cell.emissionRange = .pi / 4
                cell.spin = 2
                cell.spinRange = 3
                cell.scale = 0.12
                cell.scaleRange = 0.05
                cell.color = color.cgColor

                let size = CGSize(width: 16, height: 16)
                UIGraphicsBeginImageContext(size)
                if let context = UIGraphicsGetCurrentContext() {
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: .zero, size: size))
                }
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                cell.contents = image?.cgImage
                cells.append(cell)
            }

            emitter.emitterCells = cells
            view.layer.addSublayer(emitter)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                emitter.birthRate = 0
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
