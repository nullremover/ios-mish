
import AVFoundation
import Foundation

/// Reads small PCM windows from the currently playing file for visualization.
/// This does not play audio. AVAudioPlayer remains responsible for playback.
final class MishAudioSampler {
    private let queue = DispatchQueue(
        label: "dev.mish.audio-sampler",
        qos: .userInitiated
    )

    // Accessed only on `queue`.
    private var file: AVAudioFile?
    private var loadedURL: URL?

    func analyze(
        url: URL,
        at time: TimeInterval,
        completion: @escaping ([Float]) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            do {
                // Reuse the decoder while the same track is playing.
                if self.loadedURL != url || self.file == nil {
                    self.file = try AVAudioFile(forReading: url)
                    self.loadedURL = url
                }

                guard let file = self.file else { return }

                let format = file.processingFormat
                let sampleRate = format.sampleRate
                let fftSize = MishSpectrumAnalyzer.fftSize

                guard sampleRate > 0, file.length > 0 else {
                    DispatchQueue.main.async {
                        completion(
                            Array(
                                repeating: 0,
                                count: MishSpectrumAnalyzer.bandCount
                            )
                        )
                    }
                    return
                }

                // Center the analysis window near the playback position.
                let targetFrame = AVAudioFramePosition(
                    max(0, time) * sampleRate
                )

                let windowSize = AVAudioFramePosition(fftSize)
                let maxStart = max(0, file.length - windowSize)
                let startFrame = min(
                    max(0, targetFrame - windowSize / 2),
                    maxStart
                )

                file.framePosition = startFrame

                let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(fftSize)
                )!

                try file.read(into: buffer)

                guard let channels = buffer.floatChannelData,
                      buffer.frameLength > 0 else {
                    return
                }

                let channelCount = Int(format.channelCount)
                let frameCount = Int(buffer.frameLength)

                // Convert stereo or multichannel audio to mono.
                var samples = [Float](
                    repeating: 0,
                    count: frameCount
                )

                for frame in 0..<frameCount {
                    var mixed: Float = 0

                    for channel in 0..<channelCount {
                        mixed += channels[channel][frame]
                    }

                    samples[frame] = mixed / Float(channelCount)
                }

                let spectrum = MishSpectrumAnalyzer.analyze(
                    samples: samples,
                    sampleRate: sampleRate
                )

                DispatchQueue.main.async {
                    completion(spectrum)
                }
            } catch {
                print("Mish spectrum analysis failed: \(error)")

                DispatchQueue.main.async {
                    completion(
                        Array(
                            repeating: 0,
                            count: MishSpectrumAnalyzer.bandCount
                        )
                    )
                }
            }
        }
    }
}
