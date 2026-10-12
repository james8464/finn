import Foundation

/// Options a person can change in the app. Tests pass their own `UserDefaults` suite.
nonisolated struct PlumbPreferences: @unchecked Sendable {
    static let recognizesExerciseKey = "plumb.recognizesExercise"
    static let checksCameraAngleKey = "plumb.checksCameraAngle"

    let defaults: UserDefaults

    static let standard = PlumbPreferences(defaults: .standard)

    /// Off by default: the exercise classifier is unvalidated, so the person's choice leads.
    var recognizesExercise: Bool {
        get { defaults.bool(forKey: Self.recognizesExerciseKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.recognizesExerciseKey) }
    }

    /// On by default; a person can switch it off if the 3D angle check misjudges their setup.
    var checksCameraAngle: Bool {
        get { defaults.object(forKey: Self.checksCameraAngleKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.checksCameraAngleKey) }
    }
}
