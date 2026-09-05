import AVFoundation

@MainActor
final class AppSoundPlayer {
    enum Sound: String, CaseIterable {
        case page, click, send, tick

        var fileExtension: String { self == .page ? "mp3" : "wav" }
        var rate: Float { self == .page ? 1.6 : 1 }
        var volume: Float { self == .tick ? 0.25 : 1 }
    }

    static let shared = AppSoundPlayer()
    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {
        // Mix with other audio and respect the device's silent setting.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: sound.fileExtension),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.enableRate = true
            player.rate = sound.rate
            player.volume = sound.volume
            player.prepareToPlay()
            players[sound] = player
        }
    }

    func play(_ sound: Sound) {
        guard let player = players[sound] else { return }
        // Rapid refreshes restart this effect instead of accumulating overlapping copies.
        player.stop()
        player.currentTime = 0
        player.rate = sound.rate
        player.play()
    }

    func stop(_ sound: Sound) {
        players[sound]?.stop()
    }
}
