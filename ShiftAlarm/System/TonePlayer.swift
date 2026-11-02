import AVFoundation

/// Plays a Tone while she picks one, out loud even in silent mode, as the alarm will ring.
@MainActor
final class TonePlayer {
    private var player: AVAudioPlayer?

    /// The default sound has no public recording, so picking it only stops the playing Tone.
    func play(_ tone: Tone?) {
        stop()
        guard let tone, let url = Bundle.main.url(forResource: tone.fileName, withExtension: nil),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
        player.play()
        self.player = player
    }

    func stop() {
        guard let player else { return }
        player.stop()
        self.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
