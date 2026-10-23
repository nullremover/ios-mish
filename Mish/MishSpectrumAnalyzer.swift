
import Foundation

/// Converts mono PCM samples into frequency magnitudes.
enum MishSpectrumAnalyzer {
    static let fftSize = 2048
    static let bandCount = 512

    private static let window: [Float] = (0..<fftSize).map { i in
        0.5 - 0.5 * cos(
            2 * Float.pi * Float(i) / Float(fftSize - 1)
        )
    }

    private static let bandRanges: [(lower: Int, upper: Int)] = {
        let sampleRate = 44_100.0
        let nyquist = sampleRate / 2
        let minHz = 20.0
        let maxHz = min(16_000.0, nyquist)
        let logRange = log(maxHz / minHz)

        return (0..<bandCount).map { band in
            let lowerHz = minHz * exp(
                logRange * Double(band) / Double(bandCount)
            )
            let upperHz = minHz * exp(
                logRange * Double(band + 1) / Double(bandCount)
            )

            let lower = max(
                1,
                Int(lowerHz * Double(fftSize) / sampleRate)
            )
            let upper = min(
                fftSize / 2,
                max(lower, Int(upperHz * Double(fftSize) / sampleRate))
            )

            return (lower, upper)
        }
    }()

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

        let count = min(samples.count, n)
        let offset = samples.count - count

        for i in 0..<count {
            real[i] = samples[offset + i] * window[i]
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

        // Iterative radix-2 FFT.
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

        // Convert FFT magnitudes into display bands.
        let nyquist = sampleRate / 2
        let maxHz = min(16_000.0, nyquist)
        let logRange = maxHz > 20 ? log(maxHz / 20) : 0

        guard logRange > 0 else {
            return Array(repeating: 0, count: bandCount)
        }

        var bands = [Float](repeating: 0, count: bandCount)

        for band in 0..<bandCount {
            // Recalculate bin boundaries only for nonstandard sample rates.
            let range: (lower: Int, upper: Int)

            if abs(sampleRate - 44_100.0) < 1 {
                range = bandRanges[band]
            } else {
                let lowerHz = 20.0 * exp(
                    logRange * Double(band) / Double(bandCount)
                )
                let upperHz = 20.0 * exp(
                    logRange * Double(band + 1) / Double(bandCount)
                )

                let lower = max(
                    1,
                    Int(lowerHz * Double(n) / sampleRate)
                )
                let upper = min(
                    n / 2,
                    max(lower, Int(upperHz * Double(n) / sampleRate))
                )

                range = (lower, upper)
            }

            var peak: Float = 0

            for bin in range.lower...range.upper {
                let magnitude = sqrt(
                    real[bin] * real[bin] +
                    imag[bin] * imag[bin]
                ) / Float(n)

                peak = max(peak, magnitude)
            }

            bands[band] = min(
                1,
                log1p(peak * 80) / log(81.0)
            )
        }

        return bands
    }
}
