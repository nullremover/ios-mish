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
                    with: .color(chaos ? .black : Color(red: 3/255, green: 5/255, blue: 15/255))
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
                        scale: scale,
                        time: time
                    )
                }
            }
            .drawingGroup()
            .allowsHitTesting(false)
        }
        .background(.black)
    }

    // MARK: - CALM (Ported Desktop C++ SFML Logic)

    private func drawCalm(
        context: inout GraphicsContext,
        center: CGPoint,
        scale: CGFloat,
        time: Double
    ) {
        let spectrumCount = spectrum.count
        guard spectrumCount > 0 else { return }

        // Tuning knobs matching desktop C++ implementation (fixed 'f' suffixes)
        let calmLowBar = 90
        let calmHighBar = 470
        let calmTilt: Float = 0.5
        let calmGain: Float = 200.0
        let calmMaxWave: Float = 350.0
        let calmBaseRadius: CGFloat = 225.0 * scale
        let calmAngleOffset = Double.pi / 2.0

        let points = 128
        let halfPoints = points / 2

        func band(_ index: Int) -> Float {
            let idx = max(0, min(index, spectrumCount - 1))
            return spectrum[idx]
        }

        // --- 0. PRE-COMPUTE WAVE HEIGHTS WITH SPECTRAL TILT & SOFT-CLIPPING ---
        var wave = [CGFloat](repeating: 0, count: halfPoints + 1)
        let slotWidth = CGFloat(calmHighBar - calmLowBar) / CGFloat(halfPoints)

        for p in 0...halfPoints {
            let centerBar = CGFloat(calmLowBar) + (CGFloat(p) / CGFloat(halfPoints)) * CGFloat(calmHighBar - calmLowBar)
            let lo = max(0, Int(floor(centerBar - slotWidth)))
            let hi = min(511, Int(ceil(centerBar + slotWidth)))

            var sum: Float = 0.0
            let countInRange = max(1, hi - lo + 1)
            for b in lo...hi {
                let freq = 20.0 * pow(800.0, Float(b) / 512.0)
                let tilt = pow(freq / 1000.0, calmTilt)
                sum += band(b) * tilt
            }
            let level = sum / Float(countInRange)
            
            // Soft-clip transformation matching C++ tanh logic
            let softClipped = calmMaxWave * tanh(level * calmGain / calmMaxWave)
            wave[p] = CGFloat(softClipped) * scale
        }

        // Compute bass intensity for the reactive core
        let bassCount = min(35, spectrumCount)
        let bassSum = (0..<bassCount).reduce(0.0) { $0 + Double(spectrum[$1]) }
        let bassIntensity = bassCount > 0 ? CGFloat(bassSum / Double(bassCount)) : 0.0

        // --- 1. FILLED PORTAL MESH (Triangle Fan equivalent) ---
        var portal = Path()
        portal.move(to: center)

        for i in 0...points {
            let angle = Double(i) / Double(points) * 2.0 * Double.pi + calmAngleOffset
            let mirroredI = (i <= halfPoints) ? i : (points - i)
            let breathing = sin(time * 2.0 + Double(i) * 0.15) * 4.0 * Double(scale)
            let radius = calmBaseRadius + wave[mirroredI] + CGFloat(breathing)

            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            portal.addLine(to: point)
        }
        portal.closeSubpath()

        context.fill(
            portal,
            with: .color(Color(red: 80/255, green: 200/255, blue: 255/255).opacity(0.35))
        )

        // --- 2. OUTER WAVEFORM OUTLINE ---
        var outline = Path()

        for i in 0...points {
            let angle = Double(i) / Double(points) * 2.0 * Double.pi + calmAngleOffset
            let mirroredI = (i <= halfPoints) ? i : (points - i)
            let radius = calmBaseRadius + wave[mirroredI]

            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )

            if i == 0 {
                outline.move(to: point)
            } else {
                outline.addLine(to: point)
            }
        }
        outline.closeSubpath()

        context.stroke(
            outline,
            with: .color(Color(red: 120/255, green: 230/255, blue: 255/255).opacity(0.85)),
            lineWidth: 2 * scale
        )

        // --- 3. REACTIVE CORE ---
        let coreSize = (4.0 + bassIntensity * 8.0) * scale
        let coreRect = CGRect(
            x: center.x - coreSize,
            y: center.y - coreSize,
            width: coreSize * 2,
            height: coreSize * 2
        )

        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(Color(red: 230/255, green: 250/255, blue: 1.0).opacity(0.5))
        )
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
