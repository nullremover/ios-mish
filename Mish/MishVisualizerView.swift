
import SwiftUI

struct MishVisualizerView: View {
    let spectrum: [Float]

    let chaos: Bool

    private var energy: CGFloat {
        guard !spectrum.isEmpty else { return 0 }

        let total = spectrum.reduce(Float.zero) { $0 + $1 }
        return CGFloat(total / Float(spectrum.count))
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = CGPoint(
                x: size.width / 2,
                y: size.height / 2
            )
            let radius = min(size.width, size.height) * 0.25

            ZStack {
                Color.black

                Canvas { context, canvasSize in
                    let center = CGPoint(
                        x: canvasSize.width / 2,
                        y: canvasSize.height / 2
                    )

                    let baseRadius = min(
                        canvasSize.width,
                        canvasSize.height
                    ) * 0.25

                    // Background glow.
                    let glowRadius = baseRadius * (
                        1.5 + energy * 2.5
                    )

                    let glowRect = CGRect(
                        x: center.x - glowRadius,
                        y: center.y - glowRadius,
                        width: glowRadius * 2,
                        height: glowRadius * 2
                    )

                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .radialGradient(
                            Gradient(colors: chaos
                                ? [
                                    .purple.opacity(0.45),
                                    .pink.opacity(0.15),
                                    .clear
                                ]
                                : [
                                    .cyan.opacity(0.4),
                                    .blue.opacity(0.18),
                                    .clear
                                ]
                            ),
                            center: center,
                            startRadius: 0,
                            endRadius: glowRadius
                        )
                    )

                    let count = min(spectrum.count, 180)
                    guard count > 0 else { return }

                    // Circular spectrum.
                    var ring = Path()

                    for index in 0..<count {
                        let angle = (
                            Double(index) / Double(count) * 2 * Double.pi
                        ) - Double.pi / 2

                        let level = CGFloat(
                            spectrum[index * spectrum.count / count]
                        )

                        let inner = baseRadius * (
                            0.72 + level * (chaos ? 1.8 : 1.0)
                        )

                        let point = CGPoint(
                            x: center.x + CGFloat(cos(angle)) * inner,
                            y: center.y + CGFloat(sin(angle)) * inner
                        )

                        if index == 0 {
                            ring.move(to: point)
                        } else {
                            ring.addLine(to: point)
                        }
                    }

                    ring.closeSubpath()

                    context.stroke(
                        ring,
                        with: .color(
                            chaos
                                ? .pink.opacity(0.8)
                                : .cyan.opacity(0.8)
                        ),
                        lineWidth: chaos ? 1.5 : 2
                    )

                    // Radial frequency bars.
                    for index in 0..<count {
                        let angle = (
                            Double(index) / Double(count) * 2 * Double.pi
                        ) - Double.pi / 2

                        let level = CGFloat(
                            spectrum[index * spectrum.count / count]
                        )

                        let inner = baseRadius * 1.05
                        let outer = inner + level * (
                            chaos ? 95 : 65
                        )

                        let start = CGPoint(
                            x: center.x + CGFloat(cos(angle)) * inner,
                            y: center.y + CGFloat(sin(angle)) * inner
                        )

                        let end = CGPoint(
                            x: center.x + CGFloat(cos(angle)) * outer,
                            y: center.y + CGFloat(sin(angle)) * outer
                        )

                        var bar = Path()
                        bar.move(to: start)
                        bar.addLine(to: end)

                        let color: Color = chaos
                            ? (index.isMultiple(of: 2) ? .pink : .purple)
                            : .cyan

                        context.stroke(
                            bar,
                            with: .color(color.opacity(0.35 + level * 0.65)),
                            lineWidth: chaos ? 1.5 : 2
                        )
                    }
                }
                .drawingGroup()
                .allowsHitTesting(false)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .frame(width: size.width, height: size.height)
        }
        .background(.black)
    }
}
