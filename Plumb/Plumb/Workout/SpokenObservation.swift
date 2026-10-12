import AVFAudio
import Foundation
import Observation

nonisolated enum SpokenObservation {
    static func text(for analysis: SetAnalysis, cue: Cue?) -> String? {
        guard let cue else { return nil }
        return "\(analysis.reps.count) measured reps. \(cue.observation) \(cue.nextAction)"
    }
}

@Observable
@MainActor
final class ObservationSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    @ObservationIgnored private let synthesizer: AVSpeechSynthesizer
    @ObservationIgnored private var currentUtteranceID: ObjectIdentifier?
    private(set) var isSpeaking = false

    override init() {
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.usesApplicationAudioSession = false
        self.synthesizer = synthesizer
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        currentUtteranceID = ObjectIdentifier(utterance)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        currentUtteranceID = nil
        isSpeaking = false
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finishIfCurrent(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finishIfCurrent(utterance)
    }

    nonisolated private func finishIfCurrent(_ utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            if self?.currentUtteranceID == id {
                self?.currentUtteranceID = nil
                self?.isSpeaking = false
            }
        }
    }
}
