import AVFAudio
import Foundation
import Observation

nonisolated enum SpokenObservation {
    static func text(for analysis: SetAnalysis, cue: Cue?) -> String? {
        guard let cue else {
            return nil
        }
        return String(localized: "\(analysis.reps.count) measured reps. \(cue.observation) \(cue.nextAction)")
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
        utterance.voice = SpokenLanguage.voice
        currentUtteranceID = ObjectIdentifier(utterance)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        currentUtteranceID = nil
        isSpeaking = false
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        finishIfCurrent(utterance)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
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

/// Says the countdown, rep counts, and live observations during a set. Phrases queue so a count is
/// not cut off by the observation that follows it; when they pile up, the backlog is dropped so
/// what is said stays current with the set.
@MainActor
final class LiveAnnouncer: NSObject, LiveAnnouncing, AVSpeechSynthesizerDelegate {
    private let synthesizer: AVSpeechSynthesizer
    private var queued = 0

    override init() {
        let synthesizer = AVSpeechSynthesizer()
        // plays through the current route (AirPods or other headphones when connected) without
        // taking over the app's audio session.
        synthesizer.usesApplicationAudioSession = false
        self.synthesizer = synthesizer
        super.init()
        synthesizer.delegate = self
    }

    func announce(_ text: String) {
        if queued >= 2 {
            synthesizer.stopSpeaking(at: .immediate)
            queued = 0
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = SpokenLanguage.voice
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 1.1)
        queued += 1
        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in self?.finishOne() }
    }

    /// Only `announce` cancels, and it resets the count itself.
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {}

    private func finishOne() {
        queued = max(0, queued - 1)
    }
}
