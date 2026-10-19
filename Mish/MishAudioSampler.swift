import AVFoundation
import Foundation

/// Reads small PCM windows from an in-memory cache of the currently playing track.
/// Completely eliminates disk I/O lag during playback visualization.
final class MishAudioSampler {
    private let queue = DispatchQueue(
        label: "dev.mish.audio-sampler",
        qos: .userInitiated
    )

    // In-memory cache for the loaded track
    private var loadedURL: URL?
    private var cachedSamples: [Float] = []
    private var sampleRate: Double = 44100.0

    func analyze(
        url: URL,
        at time: TimeInterval,
        completion: @escaping ([Float]) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            do {
                // Decode the file into RAM *only* when the song changes.
                if self.loadedURL != url || self.cachedSamples.isEmpty {
                    let file = try AVAudioFile(forReading: url)
                    let format = file.processingFormat
                    self.sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100.0
                    
                    let capacity = AVAudioFrameCount(file.length)
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                        throw NSError(domain: "MishAudioSampler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PCM buffer"])
                    }
                    
                    try file.read(into: buffer)
                    
                    guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else {
                        throw NSError(domain: "MishAudioSampler", code: -2, userInfo: [NSLocalizedDescriptionKey: "No float channel data found"])
                    }
                    
                    let channelCount = Int(format.channelCount)
                    let frameCount = Int(buffer.frameLength)
                    
                    // Mix down to mono and store in RAM once
                    var monoSamples = [Float](repeating: 0, count: frameCount)
                    for frame in 0..<frameCount {
                        var mixed: Float = 0
                        for channel in 0..<channelCount {
                            mixed += channels[channel][frame]
                        }
                        monoSamples[frame] = mixed / Float(channelCount)
                    }
                    
                    self.cachedSamples = monoSamples
                    self.loadedURL = url
                }

                let fftSize = MishSpectrumAnalyzer.fftSize
                let targetFrame = Int(max(0, time) * self.sampleRate)
                let halfWindow = fftSize / 2
                
                let startFrame = max(0, targetFrame - halfWindow)
                let endFrame = min(startFrame + fftSize, self.cachedSamples.count)
                
                var samples = [Float](repeating: 0, count: fftSize)
                let actualCount = max(0, endFrame - startFrame)
                
                if actualCount > 0 {
                    samples.replaceSubrange(0..<actualCount, with: self.cachedSamples[startFrame..<endFrame])
                }

                let spectrum = MishSpectrumAnalyzer.analyze(
                    samples: samples,
                    sampleRate: self.sampleRate
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
