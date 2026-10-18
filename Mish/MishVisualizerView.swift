
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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                let center = CGPoint(
                    x: canvasSize.width / 2,
                    y: canvasSize.height / 2
                )

                let scale = min(canvasSize.width, canvasSize.height) / 390
                let baseRadius = min(canvasSize.width, canvasSize.height) * 0.25

                context.fill(
                    Path(CGRect(origin: .zero, size: canvasSize)),
                    with: .color(.black)
                )

                // Soft background glow.
                let glowRadius = baseRadius * (1.5 + energy * 2.5)
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
                                .purple.opacity(0.35),
                                .pink.opacity(0.12),
                                .clear
                            ]
                            : [
                                .cyan.opacity(0.30),
                                .blue.opacity(0.12),
                                .clear
                            ]),
                        center: center,
                        startRadius: 0,
                        endRadius: glowRadius
                    )
                )

                if chaos {
                    drawChaos(
                        context: &context,
                        center: center,
                        size: canvasSize,
                        scale: scale,
                        time: time
                    )
                } else {
                    drawCalm(
                        context: &context,
                        center: center,
                        baseRadius: baseRadius
                    )
                }
            }
            .drawingGroup()
            .allowsHitTesting(false)
        }
        .background(.black)
    }

    // MARK: - CALM

    private func drawCalm(
        context: inout GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat
    ) {
        let count = min(spectrum.count, 180)
        guard count > 0 else { return }

        var ring = Path()

        for index in 0..<count {
            let angle =
                Double(index) / Double(count) * 2 * Double.pi
                - Double.pi / 2

            let level = CGFloat(
                spectrum[index * spectrum.count / count]
            )

            let radius = baseRadius * (
                0.72 + level * 1.0
            )

            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
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
            with: .color(.cyan.opacity(0.8)),
            lineWidth: 2
        )

        for index in 0..<count {
            let angle =
                Double(index) / Double(count) * 2 * Double.pi
                - Double.pi / 2

            let level = CGFloat(
                spectrum[index * spectrum.count / count]
            )

            let inner = baseRadius * 1.05
            let outer = inner + level * 65

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

            context.stroke(
                bar,
                with: .color(.cyan.opacity(0.35 + level * 0.65)),
                lineWidth: 2
            )
        }
    }

    // MARK: - CHAOS

    private func drawChaos(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        scale: CGFloat,
        time: Double
    ) {
        guard !spectrum.isEmpty else { return }

        let count = spectrum.count

        func band(_ index: Int) -> CGFloat {
            CGFloat(spectrum[index % count])
        }

        // Estimate the three broad frequency regions.
        let bass = (0..<min(35, count))
            .reduce(CGFloat.zero) { $0 + band($1) }
            / CGFloat(min(35, count))

        let midEnd = min(220, count)
        let mids = (35..<max(36, midEnd))
            .reduce(CGFloat.zero) { $0 + band($1) }
            / CGFloat(max(1, midEnd - 35))

        let trebleStart = min(220, count - 1)
        let treble = (trebleStart..<count)
            .reduce(CGFloat.zero) { $0 + band($1) }
            / CGFloat(count - trebleStart)

        let bassPulse = min(1, bass * 3.0)
        let treblePulse = min(1, treble * 3.0)

        // 1. Geometric fracture web.
        // The web twists and breathes with time and frequency.
        let pointCount = 90
        var web = Path()

        for index in 0..<pointCount {
            let angle =
                Double(index) * 4 * Double.pi / 45
                + time * 0.8

            let magnitude = band(index * count / pointCount)

            let wave = sin(angle * 6 + time * 8) * 35 * scale
            let radius = (
                100 * scale
                + magnitude * 290 * scale
                + wave
                + CGFloat(mids) * 35 * scale
            )

            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )

            if index == 0 {
                web.move(to: point)
            } else {
                web.addLine(to: point)
            }
        }

        web.closeSubpath()

        context.stroke(
            web,
            with: .color(.purple.opacity(0.20)),
            lineWidth: 5 * scale
        )

        context.stroke(
            web,
            with: .color(.pink.opacity(0.75)),
            lineWidth: 1.2 * scale
        )

        // 2. Cross-linked geometry.
        // Connecting non-adjacent points makes the web feel fractured.
        for index in stride(from: 0, to: pointCount, by: 3) {
            let angleA =
                Double(index) * 4 * Double.pi / 45
                + time * 0.8

            let nextIndex = (index + 23) % pointCount

            let angleB =
                Double(nextIndex) * 4 * Double.pi / 45
                + time * 0.8

            let radiusA = (
                100 * scale
                + band(index * count / pointCount) * 290 * scale
            )

            let radiusB = (
                100 * scale
                + band(nextIndex * count / pointCount) * 290 * scale
            )

            let pointA = CGPoint(
                x: center.x + CGFloat(cos(angleA)) * radiusA,
                y: center.y + CGFloat(sin(angleA)) * radiusA
            )

            let pointB = CGPoint(
                x: center.x + CGFloat(cos(angleB)) * radiusB,
                y: center.y + CGFloat(sin(angleB)) * radiusB
            )

            var connection = Path()
            connection.move(to: pointA)
            connection.addLine(to: pointB)

            let hue = Double(index) / Double(pointCount)

            context.stroke(
                connection,
                with: .color(
                    Color(
                        hue: (hue + time * 0.025)
                            .truncatingRemainder(dividingBy: 1),
                        saturation: 0.95,
                        brightness: 1
                    ).opacity(0.18 + Double(magnitudeFor(index)) * 0.55)
                ),
                lineWidth: 0.8 * scale
            )
        }

        // 3. Six orbiting energy orbs.
        for orb in 0..<6 {
            let angle =
                time * 1.2
                + Double(orb) * 2 * Double.pi / 6

            let magnitude = band(orb * count / 6)
            let orbitRadius = (
                80 + magnitude * 180
            ) * scale

            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * orbitRadius,
                y: center.y + CGFloat(sin(angle)) * orbitRadius
            )

            let orbRadius = (6 + bassPulse * 10) * scale

            let hue = (
                Double(orb) / 6 + time * 0.04
            ).truncatingRemainder(dividingBy: 1)

            let orbColor = Color(
                hue: hue,
                saturation: 0.85,
                brightness: 1
            )

            let glowRect = CGRect(
                x: point.x - orbRadius * 3,
                y: point.y - orbRadius * 3,
                width: orbRadius * 6,
                height: orbRadius * 6
            )

            context.fill(
                Path(ellipseIn: glowRect),
                with: .radialGradient(
                    Gradient(colors: [
                        orbColor.opacity(0.45),
                        orbColor.opacity(0.08),
                        .clear
                    ]),
                    center: point,
                    startRadius: 0,
                    endRadius: orbRadius * 3
                )
            )

            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - orbRadius,
                    y: point.y - orbRadius,
                    width: orbRadius * 2,
                    height: orbRadius * 2
                )),
                with: .color(orbColor)
            )
        }

        // 4. Audio-reactive outward sparks.
        // Their positions are deterministic, so they don't randomly flicker.
        let sparkCount = 24

        for spark in 0..<sparkCount {
            let seed = Double(spark) * 2.399963229728653
            let angle = seed + time * (spark.isMultiple(of: 2) ? 0.35 : -0.22)

            let phase = time * 2.4 + Double(spark) * 1.7
            let pulse = max(0, sin(phase))

            let strength = max(bassPulse, treblePulse * 0.85)
            let startRadius = (30 + bassPulse * 50) * scale

            let length = (
                25
                + pulse * (80 + treblePulse * 180)
            ) * scale * strength

            guard length > 1 else { continue }

            let start = CGPoint(
                x: center.x + CGFloat(cos(angle)) * startRadius,
                y: center.y + CGFloat(sin(angle)) * startRadius
            )

            let end = CGPoint(
                x: center.x + CGFloat(cos(angle)) * (startRadius + length),
                y: center.y + CGFloat(sin(angle)) * (startRadius + length)
            )

            var sparkPath = Path()
            sparkPath.move(to: start)
            sparkPath.addLine(to: end)

            let hue = (
                Double(spark) / Double(sparkCount)
                + time * 0.09
            ).truncatingRemainder(dividingBy: 1)

            let color = Color(
                hue: hue,
                saturation: 1,
                brightness: 1
            )

            context.stroke(
                sparkPath,
                with: .color(color.opacity(0.2)),
                lineWidth: 5 * scale
            )

            context.stroke(
                sparkPath,
                with: .color(color.opacity(0.35 + pulse * 0.65)),
                lineWidth: 1.5 * scale
            )
        }

        // 5. Dark center well.
        let centerRadius = (25 + bassPulse * 15) * scale

        let centerRect = CGRect(
            x: center.x - centerRadius,
            y: center.y - centerRadius,
            width: centerRadius * 2,
            height: centerRadius * 2
        )

        context.fill(
            Path(ellipseIn: centerRect),
            with: .radialGradient(
                Gradient(colors: [
                    .black,
                    .black.opacity(0.92),
                    .black.opacity(0.05)
                ]),
                center: center,
                startRadius: 0,
                endRadius: centerRadius
            )
        )
    }

    private func magnitudeFor(_ index: Int) -> Float {
        guard !spectrum.isEmpty else { return 0 }
        return spectrum[index % spectrum.count]
    }
} 