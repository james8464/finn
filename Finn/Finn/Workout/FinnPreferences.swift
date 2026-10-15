import Foundation

nonisolated enum HapticFeedbackStyle: String, CaseIterable, Identifiable, Sendable {
    case off, gentle, regular
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: String(localized: "Off")
        case .gentle: String(localized: "Gentle")
        case .regular: String(localized: "Regular")
        }
    }
}

nonisolated enum SoundFeedbackStyle: String, CaseIterable, Identifiable, Sendable {
    case off, soft, bright
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: String(localized: "Off")
        case .soft: String(localized: "Soft")
        case .bright: String(localized: "Bright")
        }
    }
}

/// Options a person can change in the app. Tests pass their own `UserDefaults` suite.
nonisolated struct FinnPreferences: @unchecked Sendable {
    static let recognizesExerciseKey = "finn.recognizesExercise"
    static let usesTrainedModelKey = "finn.usesTrainedModel"
    static let checksCameraAngleKey = "finn.checksCameraAngle"
    static let handsFreeKey = "finn.handsFree"
    static let speaksLiveKey = "finn.speaksLive"
    static let savesToFitnessKey = "finn.savesToFitness"
    static let selectedExerciseKey = "finn.selectedExercise"
    static let personalizesWithHealthKey = "finn.personalizesWithHealth"
    static let personalizationOfferedKey = "finn.personalizationOffered"
    static let hapticFeedbackKey = "finn.hapticFeedback"
    static let soundFeedbackKey = "finn.soundFeedback"

    let defaults: UserDefaults
    /// Hands-free capture until the person changes it. On in the app, where the phone stands a
    /// few steps away; off for tests and demo input, which tap Start and Stop themselves.
    let handsFreeByDefault: Bool
    /// Whether the chosen exercise is kept for the next launch. On in the app; off for tests and demo
    /// input, which expect each model to start on the squat.
    let remembersExercise: Bool

    init(defaults: UserDefaults, handsFreeByDefault: Bool = false, remembersExercise: Bool = false) {
// keep settings selected before the product was renamed. A new value always wins.
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix("plumb.") {
            let renamedKey = "finn." + key.dropFirst("plumb.".count)
            if defaults.object(forKey: renamedKey) == nil {
                defaults.set(value, forKey: renamedKey)
            }
            defaults.removeObject(forKey: key)
        }
        self.defaults = defaults
        self.handsFreeByDefault = handsFreeByDefault
        self.remembersExercise = remembersExercise
    }

    static let standard = FinnPreferences(defaults: .standard)
    /// The app's own options: hands-free capture on unless the person turned it off.
    static let app = FinnPreferences(defaults: .standard, handsFreeByDefault: true, remembersExercise: true)

    /// The exercise chosen last time, so relaunching the app (an update from Xcode, the system closing
    /// it) does not quietly go back to the squat. Nil when nothing is remembered.
    var selectedExercise: ExerciseKind? {
        get {
            guard remembersExercise else { return nil }
            return defaults.string(forKey: Self.selectedExerciseKey).flatMap(ExerciseKind.init(rawValue:))
        }
        nonmutating set {
            guard remembersExercise else { return }
            defaults.set(newValue?.rawValue, forKey: Self.selectedExerciseKey)
        }
    }

    /// On by default: the joint-angle rules recognise the exercise after a set, and the
    /// person's choice stays whenever they are not sure.
    var recognizesExercise: Bool {
        get { defaults.object(forKey: Self.recognizesExerciseKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.recognizesExerciseKey) }
    }

    /// Off by default: a trained model, when a build includes one, is an experiment. The team
    /// chose the joint-angle rules as Finn's method on 12 October 2026.
    var usesTrainedModel: Bool {
        get { defaults.bool(forKey: Self.usesTrainedModelKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.usesTrainedModelKey) }
    }

    /// On by default; a person can switch it off if the 3D angle check misjudges their setup.
    var checksCameraAngle: Bool {
        get { defaults.object(forKey: Self.checksCameraAngleKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.checksCameraAngleKey) }
    }

    /// The set starts once the person holds still in position and ends when they walk away.
    var handsFree: Bool {
        get { defaults.object(forKey: Self.handsFreeKey) as? Bool ?? handsFreeByDefault }
        nonmutating set { defaults.set(newValue, forKey: Self.handsFreeKey) }
    }

    /// On by default: the countdown, each rep, and live observations are said aloud.
    var speaksLive: Bool {
        get { defaults.object(forKey: Self.speaksLiveKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.speaksLiveKey) }
    }

    var hapticFeedback: HapticFeedbackStyle {
        get { defaults.string(forKey: Self.hapticFeedbackKey).flatMap(HapticFeedbackStyle.init(rawValue:)) ?? .gentle }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.hapticFeedbackKey) }
    }

    var soundFeedback: SoundFeedbackStyle {
        get { defaults.string(forKey: Self.soundFeedbackKey).flatMap(SoundFeedbackStyle.init(rawValue:)) ?? .off }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.soundFeedbackKey) }
    }

    /// Off by default: a finished session is saved to Apple Health as a workout, so it appears in
    /// the Fitness app, only once the person turns this on and allows it in Health.
    var savesToFitness: Bool {
        get { defaults.bool(forKey: Self.savesToFitnessKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.savesToFitnessKey) }
    }

    /// Off by default: Finn reads heart rate, recovery, sleep, recent activity and body measurements
    /// from Health to adapt its advice, only once the person turns this on and allows it in Health.
    var personalizesWithHealth: Bool {
        get { defaults.bool(forKey: Self.personalizesWithHealthKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.personalizesWithHealthKey) }
    }

    /// Whether the one-time "Make Finn more personal?" offer was shown, whatever the answer.
    var personalizationOffered: Bool {
        get { defaults.bool(forKey: Self.personalizationOfferedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.personalizationOfferedKey) }
    }
}
