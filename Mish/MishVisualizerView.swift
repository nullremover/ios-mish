
import SwiftUI

struct MishVisualizerView: View {
    let spectrum: [Float]

    private let waveColor = Color(red: 166 / 255, green: 227 / 255, blue: 161 / 255)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }

                let centerX = size.width / 2
                let padding: CGFloat = 12
                let usableHeight = max(1, size.height - padding * 2)
                let sampleCount = max(24, min(120, Int(usableHeight / 3)))
                let middleY = size.height / 2
                let maxWidth = max(2, size.width * 0.43)

                // Quiet, nearly-black panel background.
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.035, green: 0.045, blue: 0.04))
                )

                var wave = Path()
                var fill = Path()

                fill.move(to: CGPoint(x: centerX, y: padding))

                for index in 0...sampleCount {
                    let progress = CGFloat(index) / CGFloat(sampleCount)
                    let y = padding + progress * usableHeight

                    // Map the vertical position to a spectrum band.
                    let bandIndex = spectrum.isEmpty
                        ? 0
                        : min(
                            spectrum.count - 1,
                            Int(progress * CGFloat(spectrum.count - 1))
                        )

                    let rawLevel: CGFloat = spectrum.isEmpty
                        ? 0
                        : CGFloat(max(0, spectrum[bandIndex]))

                    // Keep unusually large spectrum values from swallowing the panel.
                    let level = min(1, rawLevel * 3.5)

                    // A tiny idle movement keeps the shape from looking completely dead.
                    let idle = (
                        sin(time * 1.4 + Double(index) * 0.19) * 0.012
                        + sin(time * 0.7 + Double(index) * 0.08) * 0.008
                    )

                    let envelope = sin(Double(progress) * .pi)
                    let amplitude = min(
                        maxWidth,
                        maxWidth * (level * 0.9 + abs(idle)) * envelope
                    )

                    let point = CGPoint(
                        x: centerX + amplitude,
                        y: y
                    )

                    if index == 0 {
                        wave.move(to: point)
                    } else {
                        wave.addLine(to: point)
                    }

                    fill.addLine(to: point)
                }

                fill.addLine(to: CGPoint(x: centerX, y: padding + usableHeight))
                fill.closeSubpath()

                // Mirrored silhouette makes the waveform feel solid.
                var mirroredFill = Path()
                mirroredFill.move(to: CGPoint(x: centerX, y: padding))

                for index in 0...sampleCount {
                    let progress = CGFloat(index) / CGFloat(sampleCount)
                    let y = padding + progress * usableHeight

                    let bandIndex = spectrum.isEmpty
                        ? 0
                        : min(
                            spectrum.count - 1,
                            Int(progress * CGFloat(spectrum.count - 1))
                        )

                    let rawLevel: CGFloat = spectrum.isEmpty
                        ? 0
                        : CGFloat(max(0, spectrum[bandIndex]))

                    let level = min(1, rawLevel * 3.5)
                    let idle = (
                        sin(time * 1.4 + Double(index) * 0.19) * 0.012
                        + sin(time * 0.7 + Double(index) * 0.08) * 0.008
                    )
                    let envelope = sin(Double(progress) * .pi)
                    let amplitude = min(
                        maxWidth,
                        maxWidth * (level * 0.9 + abs(idle)) * envelope
                    )

                    mirroredFill.addLine(
                        to: CGPoint(x: centerX - amplitude, y: y)
                    )
                }

                mirroredFill.addLine(
                    to: CGPoint(x: centerX, y: padding + usableHeight)
                )
                mirroredFill.closeSubpath()

                // Soft green body, then a crisp central waveform edge.
                context.fill(
                    fill,
                    with: .color(waveColor.opacity(0.22))
                )
                context.fill(
                    mirroredFill,
                    with: .color(waveColor.opacity(0.22))
                )

                context.stroke(
                    wave,
                    with: .color(waveColor.opacity(0.95)),
                    lineWidth: 1.5
                )

                // Thin center spine gives the panel a clean visual anchor.
                var spine = Path()
                spine.move(to: CGPoint(x: centerX, y: padding))
                spine.addLine(to: CGPoint(x: centerX, y: size.height - padding))

                context.stroke(
                    spine,
                    with: .color(waveColor.opacity(0.12)),
                    lineWidth: 1
                )
            }
            .drawingGroup()
            .clipped()
        }
        .background(Color(red: 0.035, green: 0.045, blue: 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Music visualizer")
    }
}
