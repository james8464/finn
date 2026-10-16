import AVFoundation
import SwiftUI
import UIKit

/// Tactile cues for custom controls. Native controls provide their own feedback.
@MainActor
enum FinnHaptics {
    enum Cue { case selection, success }

    static func play(_ cue: Cue, preferences: FinnPreferences = .app) {
        switch preferences.hapticFeedback {
        case .off: return
        case .gentle:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: cue == .success ? 0.8 : 0.5)
        case .regular:
            switch cue {
            case .selection: UISelectionFeedbackGenerator().selectionChanged()
            case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

private struct FinnFeedbackModifier<Value: Equatable>: ViewModifier {
    let cue: FinnHaptics.Cue
    let trigger: Value

    func body(content: Content) -> some View {
        content.onChange(of: trigger) { old, new in
            if old != new { FinnHaptics.play(cue) }
        }
    }
}

extension View {
    func finnFeedback<Value: Equatable>(_ cue: FinnHaptics.Cue, trigger: Value) -> some View {
        modifier(FinnFeedbackModifier(cue: cue, trigger: trigger))
    }
}

/// Short, optional cues for workout milestones. Speech remains independent of these settings.
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
// ambient respects Silent Mode and mixes with music already playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.7
        player?.play()
    }
}
