import AVFoundation
import Foundation
import Darwin

/// Generates soft synthesized alarm sounds at runtime and writes them to
/// Library/Sounds so they can be used by both AVAudioPlayer and UNNotificationSound.
enum SoundSynthesizer {

    static let synthesizedNames = ["Meadow", "Breeze", "Drift"]

    static func ensureSynthesized() {
        guard let dir = soundsDirectory() else { return }
        let generators: [(String, () -> [Float])] = [
            ("meadow", meadow),
            ("breeze", breeze),
            ("drift",  drift),
        ]
        for (name, generate) in generators {
            let dst = dir.appendingPathComponent("rise_\(name).wav")
            guard !isValidFile(dst) else { continue }
            let samples = generate()
            try? writeWAV(samples: samples, sampleRate: sr, to: dst)
        }
    }

    // MARK: - Sound generators

    private static let sr  = 22050
    private static let dur = 29.0

    // Gentle pentatonic piano melody: C4 E4 G4 A4 C5 G4 E4 G4 …
    private static func meadow() -> [Float] {
        let n = Int(Double(sr) * dur)
        var out = [Float](repeating: 0, count: n)
        let notes: [Double] = [261.63, 329.63, 392.00, 440.00, 523.25, 392.00, 329.63, 392.00]
        let noteSamples = Int(Double(sr) * 0.65)
        let attackS     = Int(Double(sr) * 0.06)
        let decayS      = Int(Double(sr) * 0.22)

        var noteIdx = 0
        var i = 0
        while i < n {
            let freq = notes[noteIdx % notes.count]
            noteIdx += 1
            for j in 0..<noteSamples {
                guard i + j < n else { break }
                let t   = Double(j) / Double(sr)
                let phi = 2 * Double.pi * freq * t
                // Piano timbre: fundamental + harmonics
                var s = Darwin.sin(phi) * 0.65
                    + Darwin.sin(phi * 2) * 0.22
                    + Darwin.sin(phi * 3) * 0.09
                    + Darwin.sin(phi * 4) * 0.04
                // ADSR-lite envelope
                let env: Double
                if j < attackS {
                    env = Double(j) / Double(attackS)
                } else if j > noteSamples - decayS {
                    env = Double(noteSamples - j) / Double(decayS)
                } else {
                    env = 1.0
                }
                s *= env * 0.28
                out[i + j] += Float(s)
            }
            i += noteSamples
        }
        return normalize(out, peak: 0.72)
    }

    // Soft wind: three-stage low-pass filtered noise with slow amplitude swells
    private static func breeze() -> [Float] {
        let n = Int(Double(sr) * dur)
        var out = [Float](repeating: 0, count: n)
        var a = 0.0, b = 0.0, c = 0.0
        for i in 0..<n {
            let t = Double(i) / Double(sr)
            let white = Double.random(in: -1...1)
            a = a * 0.965 + white * 0.035
            b = b * 0.975 + a    * 0.025
            c = c * 0.985 + b    * 0.015
            let swell = 0.55
                + 0.28 * Darwin.sin(2 * Double.pi * 0.07  * t)
                + 0.17 * Darwin.sin(2 * Double.pi * 0.13  * t)
            out[i] = Float(c * swell * 4.5)
        }
        return normalize(out, peak: 0.65)
    }

    // Deep ambient pad: LFO-modulated root G2 with slow amplitude swell
    private static func drift() -> [Float] {
        let n  = Int(Double(sr) * dur)
        var out = [Float](repeating: 0, count: n)
        let dt  = 1.0 / Double(sr)
        var phi = 0.0
        for i in 0..<n {
            let t   = Double(i) * dt
            let lfo = Darwin.sin(2 * Double.pi * 0.055 * t)
            let freq = 98.0 + 8.0 * lfo            // G2 ± 8 Hz sweep
            phi += 2 * Double.pi * freq * dt
            let s = Darwin.sin(phi)       * 0.50
                  + Darwin.sin(phi * 1.5) * 0.20
                  + Darwin.sin(phi * 2.0) * 0.18
                  + Darwin.sin(phi * 3.0) * 0.07
                  + Darwin.sin(phi * 0.5) * 0.25
            let amp = 0.42 + 0.28 * Darwin.sin(2 * Double.pi * 0.08 * t)
            out[i] = Float(s * amp * 0.28)
        }
        return normalize(out, peak: 0.68)
    }

    // MARK: - Helpers

    private static func normalize(_ samples: [Float], peak: Float) -> [Float] {
        let maxAmp = samples.map { abs($0) }.max() ?? 1
        guard maxAmp > 0 else { return samples }
        let scale = peak / maxAmp
        return samples.map { $0 * scale }
    }

    private static func writeWAV(samples: [Float], sampleRate: Int, to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey:              kAudioFormatLinearPCM,
            AVSampleRateKey:            Double(sampleRate),
            AVNumberOfChannelsKey:      1,
            AVLinearPCMBitDepthKey:     16,
            AVLinearPCMIsFloatKey:      false,
            AVLinearPCMIsBigEndianKey:  false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let ch = buffer.floatChannelData![0]
        for i in 0..<samples.count { ch[i] = samples[i] }
        try file.write(from: buffer)
    }

    private static func isValidFile(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let file = try? AVAudioFile(forReading: url) else { return false }
        return Double(file.length) / file.processingFormat.sampleRate >= 28.0
    }

    private static func soundsDirectory() -> URL? {
        guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let dir = lib.appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
