import SwiftUI

/// how Finn looks, picked at the last question. The coach is always called Finn; only the picture
/// changes. The F monogram is the default; to add a look, add its portrait to the asset catalogue
/// and the look to `all`
nonisolated struct Coach: Identifiable, Hashable, Sendable {
    /// what `FinnPreferences` saves; never change it once shipped
    let id: String
    /// what VoiceOver says about the picture, since every look is Finn
    let look: String
    let face: Face

    nonisolated enum Face: Hashable, Sendable {
        /// a mark drawn on the round card, with a margin: Finn's F
        case monogram(String)
        /// a round portrait that fills the circle (`Design/coach-explorations-2026-10-16`)
        case portrait(String)
    }

    static let finn = Coach(id: "finn", look: String(localized: "F monogram"), face: .monogram("FinnMark"))

    /// every look, in the order the picker shows them: the F, then the ten portraits of the design
    static let all: [Coach] = [.finn] + [
        ("max", String(localized: "Short spiky hair")),
        ("nova", String(localized: "Curly ponytail and pink headband")),
        ("ines", String(localized: "Hair in a bun")),
        ("kenji", String(localized: "Round glasses")),
        ("amara", String(localized: "Short natural curls")),
        ("lea", String(localized: "Bob and pink headband")),
        ("bruno", String(localized: "Bald with a black beard")),
        ("nora", String(localized: "Short white hair")),
        ("sam", String(localized: "Dark curls")),
        ("dede", String(localized: "White moustache")),
    ].map { Coach(id: $0.0, look: $0.1, face: .portrait("Coach-\($0.0)")) }

    /// the saved coach, or Finn when nothing is saved or the coach is gone
    static func stored(_ id: String?) -> Coach {
        all.first { $0.id == id } ?? .finn
    }
}

extension EnvironmentValues {
    /// Finn's chosen look, wherever Finn speaks in the app. The onboarding sets its current
    /// answer; `ContentView` sets the saved one
    @Entry var coach: Coach = .finn
}
