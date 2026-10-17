import AVFoundation
import CancioneroCore
import Combine
import Foundation

/// Metrónomo con clic fuerte en el primer tiempo del compás.
/// El audio va en un bucle de un compás, así el pulso no se atrasa.
@MainActor
final class Metronome: ObservableObject {
    @Published private(set) var isPlaying = false
    /// Tiempo que está sonando (0 = primero del compás), para la animación.
    @Published private(set) var beat = 0
    @Published private(set) var bpm = 90
    @Published private(set) var signature = TimeSignature(beats: 4, unit: 4)

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var ticker: Timer?
    private var startedAt = Date()

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func configure(bpm: Int, signature: TimeSignature) {
        guard bpm != self.bpm || signature != self.signature else { return }
        self.bpm = TempoRange.clamp(bpm)
        self.signature = signature
        if isPlaying { start() }
    }

    func toggle() { isPlaying ? stop() : start() }

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        player.stop()
        player.scheduleBuffer(barBuffer(), at: nil, options: .loops)
        player.play()
        startedAt = Date()
        beat = 0
        isPlaying = true
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        player.stop()
        engine.pause()
        isPlaying = false
        beat = 0
    }

    private func tick() {
        let interval = 60.0 / Double(bpm)
        let current = Int(Date().timeIntervalSince(startedAt) / interval) % max(signature.beats, 1)
        if current != beat { beat = current }
    }

    /// Un compás completo: un clic por tiempo y silencio entre clics.
    private func barBuffer() -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let beatFrames = Int(rate * 60 / Double(bpm))
        let beats = max(signature.beats, 1)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(beatFrames * beats))!
        buffer.frameLength = buffer.frameCapacity
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(buffer.frameLength) { samples[i] = 0 }
        let clickFrames = min(Int(rate * 0.035), beatFrames)
        for b in 0..<beats {
            let accent = signature.isAccent(b)
            let frequency = accent ? 1_760.0 : 1_175.0
            let volume: Float = accent ? 0.9 : 0.55
            for i in 0..<clickFrames {
                let t = Double(i) / rate
                let envelope = Float(exp(-t * 90))
                samples[b * beatFrames + i] = volume * envelope * Float(sin(2 * .pi * frequency * t))
            }
        }
        return buffer
    }
}
