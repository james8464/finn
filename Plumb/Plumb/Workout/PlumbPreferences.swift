import Foundation

/// Options a person can change in the app. Tests pass their own `UserDefaults` suite.
nonisolated struct PlumbPreferences: @unchecked Sendable {
    static let recognizesExerciseKey = "plumb.recognizesExercise"
    static let usesTrainedModelKey = "plumb.usesTrainedModel"
    static let checksCameraAngleKey = "plumb.checksCameraAngle"

    let defaults: UserDefaults

    static let standard = PlumbPreferences(defaults: .standard)

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
}
