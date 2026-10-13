import Foundation

/// Options a person can change in the app. Tests pass their own `UserDefaults` suite.
nonisolated struct PlumbPreferences: @unchecked Sendable {
    static let recognizesExerciseKey = "plumb.recognizesExercise"
    static let usesTrainedModelKey = "plumb.usesTrainedModel"
    static let checksCameraAngleKey = "plumb.checksCameraAngle"
    static let handsFreeKey = "plumb.handsFree"
    static let speaksLiveKey = "plumb.speaksLive"

    let defaults: UserDefaults
    /// Hands-free capture until the person changes it. On in the app, where the phone stands a
    /// few steps away; off for tests and demo input, which tap Start and Stop themselves.
    let handsFreeByDefault: Bool

    init(defaults: UserDefaults, handsFreeByDefault: Bool = false) {
        self.defaults = defaults
        self.handsFreeByDefault = handsFreeByDefault
    }

    static let standard = PlumbPreferences(defaults: .standard)
    /// The app's own options: hands-free capture on unless the person turned it off.
    static let app = PlumbPreferences(defaults: .standard, handsFreeByDefault: true)

    /// On by default: the joint-angle rules recognize the exercise after a set, and the
    /// person's choice stays whenever they are not sure.
    var recognizesExercise: Bool {
        get { defaults.object(forKey: Self.recognizesExerciseKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.recognizesExerciseKey) }
    }

    /// Off by default: a trained model, when a build includes one, is an experiment. The team
    /// chose the joint-angle rules as Plumb's method on 12 October 2026.
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
}
