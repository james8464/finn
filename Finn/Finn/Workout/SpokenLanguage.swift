import AVFAudio
import Foundation

/// The language Finn's interface runs in, so spoken reps and observations use a voice of that
/// language instead of the system voice, which can be English while the app is in French.
nonisolated enum SpokenLanguage {
    /// The localization the app bundle resolved, such as "fr" or "en".
    static var appLanguage: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// A voice for the app's language, preferring the person's region (fr-CA, en-GB) when it is
    /// installed. Nil lets AVSpeechSynthesizer fall back to its default voice.
    static var voice: AVSpeechSynthesisVoice? {
        let language = appLanguage
        if language.contains("-") { return AVSpeechSynthesisVoice(language: language) }
        if let region = Locale.current.region?.identifier,
           let voice = AVSpeechSynthesisVoice(language: "\(language)-\(region)") {
            return voice
        }
        return AVSpeechSynthesisVoice(language: language)
    }
}

nonisolated extension JointRole {
    /// The joint's name as shown and said, capitalised: "Hip", "Hanche".
    var localisedName: String {
        switch self {
        case .shoulder: String(localized: "Shoulder")
        case .elbow: String(localized: "Elbow")
        case .wrist: String(localized: "Wrist")
        case .hip: String(localized: "Hip")
        case .knee: String(localized: "Knee")
        case .ankle: String(localized: "Ankle")
        }
    }
}
