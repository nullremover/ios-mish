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

                context.fill(
                    Path(CGRect(origin: .zero, size: canvasSize)),
                    with: .color(chaos ? .black : Color(red: 3/255, green: 5/255, blue: 15/255))
                )

                if chaos {
                    drawDesktopChaos(
                        context: &context,
                        center: center,
                        scale: scale,
                        time: time
                    )
                } else {
                    drawDesktopCalm(
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

    // MARK: - DESKTOP CALM MODE PORT

    private func drawDesktopCalm(
        context: inout GraphicsContext,
        center: CGPoint,
        scale: CGFloat,
        time: Double
    ) {
        let spectrumCount = spectrum.count
        
        let calmLowBar = 90
        let calmHighBar = 470
        let calmTilt: Float = 0.5
        let calmGain: Float = 450.0
        let calmMaxWave: Float = 420.0
        let calmBaseRadius: CGFloat = 200.0 * scale
        let calmAngleOffset = Double.pi / 2.0

        let points = 128
        let halfPoints = points / 2

        func band(_ index: Int) -> Float {
            guard spectrumCount > 0 else { return 0.05 }
            let idx = max(0, min(index, spectrumCount - 1))
            return max(0.05, spectrum[idx])
        }

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
            
            let softClipped = calmMaxWave * tanh(level * calmGain / calmMaxWave)
            wave[p] = CGFloat(softClipped) * scale
        }

        let bassCount = min(35, spectrumCount)
        let bassSum = bassCount > 0 ? (0..<bassCount).reduce(0.0) { $0 + Double(spectrum[$1]) } : 0.1
        let bassIntensity = CGFloat(bassSum / Double(max(1, bassCount))) + 0.2

        // 1. Filled Portal Mesh
        var portal = Path()
        portal.move(to: center)

        for i in 0...points {
            let angle = Double(i) / Double(points) * 2.0 * Double.pi + calmAngleOffset
            let mirroredI = (i <= halfPoints) ? i : (points - i)
            let idleMotion = sin(time * 3.0 + Double(i) * 0.2) * (12.0 + Double(bassIntensity) * 25.0)
            let breathing = sin(time * 2.0 + Double(i) * 0.15) * 6.0 * Double(scale)
            let radius = calmBaseRadius + wave[mirroredI] + CGFloat(idleMotion + breathing)

            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            portal.addLine(to: point)
        }
        portal.closeSubpath()

        context.fill(
            portal,
            with: .color(Color(red: 80/255, green: 200/255, blue: 255/255).opacity(0.45))
        )

        // 2. Outer Waveform Outline
        var outline = Path()

        for i in 0...points {
            let angle = Double(i) / Double(points) * 2.0 * Double.pi + calmAngleOffset
            let mirroredI = (i <= halfPoints) ? i : (points - i)
            let idleMotion = sin(time * 3.0 + Double(i) * 0.2) * (12.0 + Double(bassIntensity) * 25.0)
            let radius = calmBaseRadius + wave[mirroredI] + CGFloat(idleMotion)

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
            with: .color(Color(red: 120/255, green: 230/255, blue: 255/255).opacity(0.95)),
            lineWidth: 2.5 * scale
        )

        // 3. Reactive Core
        let coreSize = (6.0 + bassIntensity * 16.0) * scale
        let coreRect = CGRect(
            x: center.x - coreSize,
            y: center.y - coreSize,
            width: coreSize * 2,
            height: coreSize * 2
        )

        context.fill(
            Path(ellipseIn: coreRect),
            with: .color(Color(red: 230/255, green: 250/255, blue: 1.0).opacity(0.7))
        )
    }

    // MARK: - DESKTOP CHAOS MODE PORT

    private func drawDesktopChaos(
        context: inout GraphicsContext,
        center: CGPoint,
        scale: CGFloat,
        time: Double
    ) {
        let count = spectrum.count

        func band(_ index: Int) -> CGFloat {
            guard count > 0 else { return 0.1 }
            let idx = max(0, min(index, count - 1))
            return CGFloat(max(0.08, spectrum[idx]))
        }

        let bass = count > 0 ? (0..<min(35, count)).reduce(CGFloat.zero) { $0 + band($1) } / CGFloat(min(35, count)) : 0.2
        let treble = count > 0 ? (min(220, count - 1)..<count).reduce(CGFloat.zero) { $0 + band($1) } / CGFloat(max(1, count - min(220, count - 1))) : 0.2

        let bassPulse = max(0.3, min(1.0, bass * 4.0))
        let treblePulse = max(0.3, min(1.0, treble * 4.0))

        let driftX = sin(time * 1.5) * 18.0
        let driftY = cos(time * 1.8) * 18.0
        let jitterX = (Double(arc4random_uniform(1000)) / 1000.0 - 0.5) * 22.0 * Double(bass)
        let jitterY = (Double(arc4random_uniform(1000)) / 1000.0 - 0.5) * 22.0 * Double(bass)

        let cycloneCenter = CGPoint(
            x: center.x + CGFloat(driftX + jitterX),
            y: center.y + CGFloat(driftY + jitterY)
        )

        let zoomFactor = 0.95 + (Double(bass) * 0.1)
        let spinDirection: Double = (sin(time * 0.5) > 0.0) ? 1.0 : -1.0
        let rotationDelta = (1.5 + Double(treble) * 12.0) * spinDirection
        let cycloneRotation = Angle(degrees: (time * rotationDelta * 15.0).truncatingRemainder(dividingBy: 360.0))

        context.drawLayer { subcontext in
            subcontext.translateBy(x: cycloneCenter.x, y: cycloneCenter.y)
            subcontext.rotate(by: cycloneRotation)
            subcontext.scaleBy(x: CGFloat(zoomFactor), y: CGFloat(zoomFactor))
            subcontext.translateBy(x: -cycloneCenter.x, y: -cycloneCenter.y)

            // 1. Geometric Fracture Web
            let pointCount = 90
            var web = Path()
            for index in 0..<pointCount {
                let angle = Double(index) * 4 * Double.pi / 45 + time * 1.2
                let magnitude = band(index * max(1, count) / pointCount)
                let wave = sin(angle * 6 + time * 10) * 45 * scale
                let radius = (80 * scale + magnitude * 340 * scale + wave)

                let point = CGPoint(
                    x: cycloneCenter.x + CGFloat(cos(angle)) * radius,
                    y: cycloneCenter.y + CGFloat(sin(angle)) * radius
                )
                if index == 0 {
                    web.move(to: point)
                } else {
                    web.addLine(to: point)
                }
            }
            web.closeSubpath()
            subcontext.stroke(web, with: .color(.purple.opacity(0.35)), lineWidth: 6 * scale)
            subcontext.stroke(web, with: .color(.pink.opacity(0.95)), lineWidth: 1.8 * scale)

            // 2. Orbiting Energy Orbs
            for orb in 0..<6 {
                let angle = time * 1.8 + Double(orb) * 2 * Double.pi / 6
                let magnitude = band(orb * max(1, count) / 6)
                let orbitRadius = (70 + magnitude * 220) * scale

                let point = CGPoint(
                    x: cycloneCenter.x + CGFloat(cos(angle)) * orbitRadius,
                    y: cycloneCenter.y + CGFloat(sin(angle)) * orbitRadius
                )

                let orbRadius = (8 + bassPulse * 14) * scale
                let hue = (Double(orb) / 6 + time * 0.08).truncatingRemainder(dividingBy: 1)
                let orbColor = Color(hue: hue, saturation: 0.9, brightness: 1)

                subcontext.fill(
                    Path(ellipseIn: CGRect(x: point.x - orbRadius, y: point.y - orbRadius, width: orbRadius * 2, height: orbRadius * 2)),
                    with: .color(orbColor)
                )
            }

            // 3. Neon Sparks
            let sparkCount = 20
            for spark in stride(from: 0, to: sparkCount, by: 2) {
                let seed = Double(spark) * 2.39
                let angle = seed + time * 0.6
                let startDist = 25.0 + Double(bassPulse) * 40.0
                let endDist = startDist + 100.0 + Double(treblePulse) * 220.0

                let start = CGPoint(x: cycloneCenter.x + CGFloat(cos(angle) * startDist), y: cycloneCenter.y + CGFloat(sin(angle) * startDist))
                let end = CGPoint(x: cycloneCenter.x + CGFloat(cos(angle) * endDist), y: cycloneCenter.y + CGFloat(sin(angle) * endDist))

                var sparkPath = Path()
                sparkPath.move(to: start)
                sparkPath.addLine(to: end)

                subcontext.stroke(sparkPath, with: .color(.pink.opacity(0.9)), lineWidth: 2 * scale)
            }

            // 4. Void Portal Center Well
            let centerRadius = (30 + bassPulse * 20) * scale
            subcontext.fill(
                Path(ellipseIn: CGRect(x: cycloneCenter.x - centerRadius, y: cycloneCenter.y - centerRadius, width: centerRadius * 2, height: centerRadius * 2)),
                with: .radialGradient(
                    Gradient(colors: [.black, .black.opacity(0.95), .black.opacity(0.1)]),
                    center: cycloneCenter,
                    startRadius: 0,
                    endRadius: centerRadius
                )
            )
        }
    }
}
