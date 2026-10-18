
import Foundation

/// Converts audio samples into frequency magnitudes for Mish's visualizer.
/// Input samples should be mono Float audio, ideally normalized to -1...1.
enum MishSpectrumAnalyzer {
    static let fftSize = 2048
    static let bandCount = 512

    static func analyze(
        samples: [Float],
        sampleRate: Double
    ) -> [Float] {
        guard sampleRate > 0, !samples.isEmpty else {
            return Array(repeating: 0, count: bandCount)
        }

        let n = fftSize
        var real = [Float](repeating: 0, count: n)
        var imag = [Float](repeating: 0, count: n)

        // Keep the newest samples and pad short buffers with silence.
        let count = min(samples.count, n)
        let offset = samples.count - count

        for i in 0..<count {
            let window = 0.5 - 0.5 * cos(
                2 * Float.pi * Float(i) / Float(n - 1)
            )

            real[i] = samples[offset + i] * window
        }

        // Bit-reversal permutation.
        var j = 0

        for i in 1..<n {
            var bit = n >> 1

            while j & bit != 0 {
                j ^= bit
                bit >>= 1
            }

            j ^= bit

            if i < j {
                real.swapAt(i, j)
                imag.swapAt(i, j)
            }
        }

        // Iterative radix-2 Cooley-Tukey FFT.
        var length = 2

        while length <= n {
            let angle = -2 * Float.pi / Float(length)
            let half = length / 2

            for start in stride(from: 0, to: n, by: length) {
                for k in 0..<half {
                    let phase = angle * Float(k)
                    let wr = cos(phase)
                    let wi = sin(phase)

                    let even = start + k
                    let odd = even + half

                    let tr = wr * real[odd] - wi * imag[odd]
                    let ti = wr * imag[odd] + wi * real[odd]

                    let er = real[even]
                    let ei = imag[even]

                    real[even] = er + tr
                    imag[even] = ei + ti
                    real[odd] = er - tr
                    imag[odd] = ei - ti
                }
            }

            length *= 2
        }

        // Map the FFT into logarithmically spaced frequency bands.
        let nyquist = sampleRate / 2
        let minHz = 20.0
        let maxHz = min(16_000.0, nyquist)
        var bands = [Float](repeating: 0, count: bandCount)

        guard maxHz > minHz else { return bands }

        let logRange = log(maxHz / minHz)

        for band in 0..<bandCount {
            let lowerHz = minHz * exp(
                logRange * Double(band) / Double(bandCount)
            )
            let upperHz = minHz * exp(
                logRange * Double(band + 1) / Double(bandCount)
            )

            let lowerBin = max(
                1,
                Int(lowerHz * Double(n) / sampleRate)
            )
            let upperBin = min(
                n / 2,
                max(lowerBin, Int(upperHz * Double(n) / sampleRate))
            )

            var peak: Float = 0

            for bin in lowerBin...upperBin {
                let magnitude = sqrt(
                    real[bin] * real[bin] +
                    imag[bin] * imag[bin]
                ) / Float(n)

                peak = max(peak, magnitude)
            }

            // Gentle logarithmic scaling for visual display.
            bands[band] = min(
                1,
                log1p(peak * 80) / log(81.0)
            )
        }

        return bands
    }
}
