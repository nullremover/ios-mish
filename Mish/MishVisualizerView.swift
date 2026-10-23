
import SwiftUI

struct MishVisualizerView: View {
    let spectrum: [Float]

    private let waveColor = Color(
        red: 166.0 / 255.0,
        green: 227.0 / 255.0,
        blue: 161.0 / 255.0
    )

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else {
                return
            }

            let centerX = size.width / 2
            let padding: CGFloat = 8
            let usableHeight = max(1, size.height - padding * 2)
            let sampleCount = min(64, max(24, Int(usableHeight / 4)))
            let maxWidth = size.width * 0.4

            let background = Color(
                red: 0.035,
                green: 0.045,
                blue: 0.04
            )

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(background)
            )

            var amplitudes: [CGFloat] = []
            amplitudes.reserveCapacity(sampleCount + 1)

            for index in 0...sampleCount {
                let progress = CGFloat(index) / CGFloat(sampleCount)

                let magnitude: CGFloat

                if spectrum.isEmpty {
                    magnitude = 0
                } else {
                    let bandIndex = min(
                        spectrum.count - 1,
                        Int(progress * CGFloat(spectrum.count - 1))
                    )

                    magnitude = min(
                        1,
                        max(0, CGFloat(spectrum[bandIndex]) * 3.5)
                    )
                }

                let envelope = pow(
                    max(0, sin(Double(progress) * .pi)),
                    0.65
                )

                amplitudes.append(
                    maxWidth * magnitude * 0.9 * envelope
                )
            }

            var waveform = Path()

            for index in 0...sampleCount {
                let progress = CGFloat(index) / CGFloat(sampleCount)
                let y = padding + progress * usableHeight

                let point = CGPoint(
                    x: centerX + amplitudes[index],
                    y: y
                )

                if index == 0 {
                    waveform.move(to: point)
                } else {
                    waveform.addLine(to: point)
                }
            }

            for index in stride(
                from: sampleCount,
                through: 0,
                by: -1
            ) {
                let progress = CGFloat(index) / CGFloat(sampleCount)
                let y = padding + progress * usableHeight

                waveform.addLine(
                    to: CGPoint(
                        x: centerX - amplitudes[index],
                        y: y
                    )
                )
            }

            waveform.closeSubpath()

            context.fill(
                waveform,
                with: .color(waveColor.opacity(0.24))
            )

            context.stroke(
                waveform,
                with: .color(waveColor.opacity(0.95)),
                lineWidth: 1.2
            )
        }
        .background(
            Color(red: 0.035, green: 0.045, blue: 0.04)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Music visualizer")
    }
}
