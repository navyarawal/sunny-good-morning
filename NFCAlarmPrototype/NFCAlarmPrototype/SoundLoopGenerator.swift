import AVFoundation
import Foundation

/// Builds ~29-second looped versions of the bundled alarm WAVs and writes them
/// to Library/Sounds — that's the directory iOS resolves UNNotificationSound(named:)
/// against. Without this, each chain notification only rings for the source's
/// 5–14 seconds, leaving silent gaps between the 30s-spaced chain links.
enum SoundLoopGenerator {

    private static let targetDuration: Double = 29.0  // iOS hard cap is 30; leave headroom
    private static let minAcceptableDuration: Double = 28.0
    private static let maxAcceptableDuration: Double = 29.5

    static func ensureLoops(ringtoneNames: [String]) {
        guard let dir = soundsDirectory() else { return }
        for name in ringtoneNames {
            let lower = name.lowercased()
            let dst = dir.appendingPathComponent("rise_\(lower).wav")
            if existsAndUsableDuration(dst) { continue }
            guard let src = Bundle.main.url(forResource: "rise_\(lower)", withExtension: "wav") else { continue }
            try? buildLoop(from: src, to: dst)
        }
    }

    // MARK: - Internals

    private static func existsAndUsableDuration(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let file = try? AVAudioFile(forReading: url) else { return false }
        let dur = Double(file.length) / file.processingFormat.sampleRate
        return dur >= minAcceptableDuration && dur <= maxAcceptableDuration
    }

    private static func soundsDirectory() -> URL? {
        guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let dir = lib.appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func buildLoop(from src: URL, to dst: URL) throws {
        let srcFile = try AVAudioFile(forReading: src)
        let format = srcFile.processingFormat
        let frameCount = AVAudioFrameCount(srcFile.length)
        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        try srcFile.read(into: srcBuffer)

        applyLoopFade(srcBuffer)

        // Output settings: 16-bit PCM WAV at the source sample rate, mono if source is mono
        let channels = Int(format.channelCount)
        let outSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        try? FileManager.default.removeItem(at: dst)
        let dstFile = try AVAudioFile(forWriting: dst, settings: outSettings)

        let totalFrames = AVAudioFrameCount(format.sampleRate * targetDuration)
        var written: AVAudioFrameCount = 0
        while written < totalFrames {
            let remaining = totalFrames - written
            let chunk = min(remaining, srcBuffer.frameLength)
            if chunk == srcBuffer.frameLength {
                try dstFile.write(from: srcBuffer)
            } else {
                // Final partial write — slice the buffer
                guard let partial = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { break }
                partial.frameLength = chunk
                copyFrames(from: srcBuffer, to: partial, count: chunk)
                try dstFile.write(from: partial)
            }
            written += chunk
        }
    }

    /// Apply a 50ms linear fade-in at the start and fade-out at the end so loop
    /// boundaries don't click. Mutates the buffer in place.
    private static func applyLoopFade(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let sampleRate = buffer.format.sampleRate
        let fadeFrames = Int(0.050 * sampleRate)
        let total = Int(buffer.frameLength)
        guard fadeFrames * 2 < total else { return }

        for ch in 0..<Int(buffer.format.channelCount) {
            let samples = channelData[ch]
            for i in 0..<fadeFrames {
                let gain = Float(i) / Float(fadeFrames)
                samples[i] *= gain
                samples[total - 1 - i] *= gain
            }
        }
    }

    private static func copyFrames(from src: AVAudioPCMBuffer, to dst: AVAudioPCMBuffer, count: AVAudioFrameCount) {
        guard let s = src.floatChannelData, let d = dst.floatChannelData else { return }
        for ch in 0..<Int(src.format.channelCount) {
            memcpy(d[ch], s[ch], Int(count) * MemoryLayout<Float>.size)
        }
    }
}
