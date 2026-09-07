import CoreHaptics
import Foundation

/// Low-sharpness haptics follow the finger, independently of the audio player.
@MainActor
final class BreathHaptics {
    static let shared = BreathHaptics()
    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var modulation: Task<Void, Never>?
    private var beganAt: TimeInterval?
    private var releasedAt: TimeInterval?
    private var releaseIntensity: Float = 0
    private var currentIntensity: Float = 0

    private init() {}

    func prepare() {
        guard supported else { return }
        do {
            if engine == nil {
                let created = try CHHapticEngine()
                created.playsHapticsOnly = true
                created.isAutoShutdownEnabled = true
                created.stoppedHandler = { [weak self] _ in
                    Task { @MainActor in self?.stopPlayer() }
                }
                created.resetHandler = { [weak self] in
                    // Server resets invalidate every player. Resume only on another deliberate press.
                    Task { @MainActor in self?.stopPlayer() }
                }
                engine = created
            }
            try engine?.start()
        } catch {
            stopPlayer()
        }
    }

    func begin() {
        guard supported else { return }
        stopPlayer()
        prepare()
        guard let engine else { return }
        do {
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.03)
            ], relativeTime: 0, duration: 30)
            let pattern = try CHHapticPattern(events: [event], parameters: [
                CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0, relativeTime: 0)
            ])
            let newPlayer = try engine.makeAdvancedPlayer(with: pattern)
            newPlayer.loopEnabled = true
            newPlayer.loopEnd = 30
            player = newPlayer
            try newPlayer.start(atTime: CHHapticTimeImmediate)
            beganAt = ProcessInfo.processInfo.systemUptime
            modulation = Task { @MainActor [weak self] in
                do {
                    while !Task.isCancelled {
                        guard self?.updateIntensity() == true else { return }
                        try await Task.sleep(nanoseconds: 25_000_000)
                    }
                } catch { return }
            }
        } catch {
            stopPlayer()
        }
    }

    func release() {
        guard player != nil, beganAt != nil, releasedAt == nil else { return }
        releaseIntensity = currentIntensity
        releasedAt = ProcessInfo.processInfo.systemUptime
    }

    func cancel() {
        stopPlayer()
        engine?.stop(completionHandler: nil)
    }

    private func updateIntensity() -> Bool {
        guard let player, let start = beganAt else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        let intensity: Float
        if let release = releasedAt {
            let progress = min(1, max(0, now - release))
            if progress >= 1 {
                stopPlayer()
                return false
            }
            intensity = releaseIntensity * Float(1 - progress)
        } else {
            let elapsed = max(0, now - start)
            let t = min(1, elapsed / 6)
            let rise = t * t * (3 - 2 * t)
            let pulse = 0.65 + 0.35 * sin(2 * .pi * elapsed / 0.7)
            let onset = min(1, elapsed / 0.15)
            // Gentle undulations grow over six seconds and then remain capped, even on a long hold.
            intensity = Float((0.07 + 0.21 * rise) * pulse * onset)
        }
        do {
            try player.sendParameters([
                CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0)
            ], atTime: CHHapticTimeImmediate)
            currentIntensity = intensity
            return true
        } catch {
            stopPlayer()
            return false
        }
    }

    private func stopPlayer() {
        modulation?.cancel()
        modulation = nil
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        beganAt = nil
        releasedAt = nil
        currentIntensity = 0
    }
}
