import AVFoundation
import UIKit

/// short, optional cues for workout milestones. Speech remains independent of these settings.
@MainActor
final class WorkoutFeedback {
    enum Event {
        case rep, setStarted, setFinished
    }

    private var player: AVAudioPlayer?

    func play(_ event: Event, haptics: HapticFeedbackStyle, sound: SoundFeedbackStyle) {
        if haptics != .off {
            let impact: UIImpactFeedbackGenerator
            switch haptics {
            case .off: return
            case .gentle: impact = UIImpactFeedbackGenerator(style: .soft)
            case .regular: impact = UIImpactFeedbackGenerator(style: .light)
            }
            impact.impactOccurred(intensity: event == .rep ? 0.55 : 0.8)
        }

        guard sound != .off, event != .rep else { return }
        let name: String
        switch (sound, event) {
        case (.soft, .setStarted): name = "feedback-soft-start"
        case (.soft, .setFinished): name = "feedback-soft-finish"
        case (.bright, .setStarted): name = "feedback-bright-start"
        case (.bright, .setFinished): name = "feedback-bright-finish"
        default: return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        // ambient respects Silent Mode and mixes with music already playing
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.7
        player?.play()
    }
}
