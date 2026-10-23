import AVFoundation

/// 编辑页里试听铃声用。
final class SoundPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    func preview(_ option: SoundOption) {
        guard let fileName = option.fileName else { return }
        let name = (fileName as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            player = nil
        }
    }
}
