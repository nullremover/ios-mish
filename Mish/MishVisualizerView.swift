
import SwiftUI

struct MishVisualizerView: View {
    let spectrum: [Float]

    private let waveColor = Color(
        red: 166.0 / 255.0,
        green: 227.0 / 255.0,
        blue: 161.0 / 255.0
    )

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }

                let time = timeline.date.timeIntervalSinceReferenceDate
                let centerX = size.width / 2
                let padding: CGFloat = 12
                let usableHeight = max(1, size.height - padding * 2)
                let sampleCount = max(32, min(160, Int(usableHeight / 2)))
                let maxWidth = size.width * 0.40

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.035, green: 0.045, blue: 0.04))
                )

                var silhouette = Path()

                for index in 0...sampleCount {
                    let progress = CGFloat(index) / CGFloat(sampleCount)
                    let y = padding + progress * usableHeight

                    let bandIndex = spectrum.isEmpty
                        ? 0
                        : min(
                            spectrum.count - 1,
                            Int(progress * CGFloat(spectrum.count - 1))
                        )

                    let magnitude: CGFloat = spectrum.isEmpty
                        ? 0
                        : min(1, max(0, CGFloat(spectrum[bandIndex]) * 3.5))

                    let envelope = pow(max(0, sin(Double(progress) * .pi)), 0.65)
                    let idle = abs(sin(time * 1.3 + Double(index) * 0.17)) * 0.012

                    let amplitude = maxWidth
                        * min(1, magnitude * 0.9 + idle)
                        * envelope

                    let right = CGPoint(x: centerX + amplitude, y: y)
                    let left = CGPoint(x: centerX - amplitude, y: y)

                    if index == 0 {
                        silhouette.move(to: right)
                    } else {
                        silhouette.addLine(to: right)
                    }

                    // Save the mirrored edge so the shape closes into one solid wave.
                    _ = left
                }

                for index in stride(from: sampleCount, through: 0, by: -1) {
                    let progress = CGFloat(index) / CGFloat(sampleCount)
                    let y = padding + progress * usableHeight

                    let bandIndex = spectrum.isEmpty
                        ? 0
                        : min(
                            spectrum.count - 1,
                            Int(progress * CGFloat(spectrum.count - 1))
                        )

                    let magnitude: CGFloat = spectrum.isEmpty
                        ? 0
                        : min(1, max(0, CGFloat(spectrum[bandIndex]) * 3.5))

                    let envelope = pow(max(0, sin(Double(progress) * .pi)), 0.65)
                    let idle = abs(sin(time * 1.3 + Double(index) * 0.17)) * 0.012

                    let amplitude = maxWidth
                        * min(1, magnitude * 0.9 + idle)
                        * envelope

                    silhouette.addLine(
                        to: CGPoint(x: centerX - amplitude, y: y)
                    )
                }

                silhouette.closeSubpath()

                context.fill(
                    silhouette,
                    with: .color(waveColor.opacity(0.24))
                )

                context.stroke(
                    silhouette,
                    with: .color(waveColor.opacity(0.95)),
                    lineWidth: 1.4
                )

                var centerLine = Path()
                centerLine.move(to: CGPoint(x: centerX, y: padding))
                centerLine.addLine(
                    to: CGPoint(x: centerX, y: size.height - padding)
                )

                context.stroke(
                    centerLine,
                    with: .color(waveColor.opacity(0.13)),
                    lineWidth: 1
                )
            }
            .drawingGroup()
            .clipped()
        }
        .background(Color(red: 0.035, green: 0.045, blue: 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Music visualizer")
    }
}
