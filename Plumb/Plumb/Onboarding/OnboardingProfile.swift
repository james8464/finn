import Foundation

/// What the person wants from Plumb, asked once at the first launch.
nonisolated enum TrainingGoal: String, Codable, CaseIterable, Sendable {
    case technique
    case consistency
    case strength
    case comeback

    var title: String {
        switch self {
        case .technique: String(localized: "Cleaner technique")
        case .consistency: String(localized: "Train more regularly")
        case .strength: String(localized: "Get stronger")
        case .comeback: String(localized: "Come back after a break")
        }
    }

    var detail: String {
        switch self {
        case .technique: String(localized: "See what each set looked like and change one thing at a time.")
        case .consistency: String(localized: "Short sets, often. Plumb keeps the history.")
        case .strength: String(localized: "More reps over time, with a range you can repeat.")
        case .comeback: String(localized: "Start light and compare with your own earlier sets.")
        }
    }

    var symbol: String {
        switch self {
        case .technique: "scope"
        case .consistency: "calendar"
        case .strength: "figure.strengthtraining.traditional"
        case .comeback: "arrow.uturn.forward"
        }
    }
}

/// How used to these exercises the person is. Changes the coach's wording, nothing it measures.
nonisolated enum TrainingLevel: String, Codable, CaseIterable, Sendable {
    case new
    case regular
    case experienced

    var title: String {
        switch self {
        case .new: String(localized: "New to this")
        case .regular: String(localized: "I train now and then")
        case .experienced: String(localized: "I train often")
        }
    }

    var detail: String {
        switch self {
        case .new: String(localized: "Explain each cue.")
        case .regular: String(localized: "Brief cues with measurements.")
        case .experienced: String(localized: "Range, tempo and set comparisons.")
        }
    }
}

/// The answers of the first launch, read from and written to `PlumbPreferences`.
nonisolated struct OnboardingProfile: Equatable, Sendable {
    var goal: TrainingGoal?
    var level: TrainingLevel?
    /// Exercises the person picked, in the order of the picker. Empty means no preference.
    var favoriteExercises: [ExerciseKind] = []
    var speaksLive = true

    /// The exercises in the order the first screen shows them: favorites first, then the rest.
    var exerciseOrder: [ExerciseKind] {
        favoriteExercises + ExerciseKind.allCases.filter { !favoriteExercises.contains($0) }
    }

    /// One sentence added to the coach's instructions, so its tone follows the answers. Nil when the
    /// person skipped both questions.
    var coachNote: String? {
        var parts: [String] = []
        switch level {
        case .new?: parts.append("The person is new to these exercises: explain each cue in plain words, one at a time.")
        case .regular?: parts.append("The person trains now and then: keep cues short and give the number behind each one.")
        case .experienced?: parts.append("The person trains often: lead with numbers (range, tempo, comparison) and skip basics.")
        case nil: break
        }
        switch goal {
        case .technique?: parts.append("Their goal is cleaner technique.")
        case .consistency?: parts.append("Their goal is to train more regularly; notice when they come back.")
        case .strength?: parts.append("Their goal is to get stronger: more reps over time with a repeatable range.")
        case .comeback?: parts.append("They are coming back after a break: suggest starting light, never push.")
        case nil: break
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

extension PlumbPreferences {
    static let onboardingCompletedKey = "plumb.onboardingCompleted"
    static let trainingGoalKey = "plumb.trainingGoal"
    static let trainingLevelKey = "plumb.trainingLevel"
    static let favoriteExercisesKey = "plumb.favoriteExercises"

    /// True once the person finished or skipped the first-launch screens.
    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Self.onboardingCompletedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.onboardingCompletedKey) }
    }

    var trainingGoal: TrainingGoal? {
        get { defaults.string(forKey: Self.trainingGoalKey).flatMap(TrainingGoal.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.trainingGoalKey) }
    }

    var trainingLevel: TrainingLevel? {
        get { defaults.string(forKey: Self.trainingLevelKey).flatMap(TrainingLevel.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.trainingLevelKey) }
    }

    /// The exercises picked at the first launch, in order. Unknown values from a later build are dropped.
    var favoriteExercises: [ExerciseKind] {
        get { (defaults.stringArray(forKey: Self.favoriteExercisesKey) ?? []).compactMap(ExerciseKind.init(rawValue:)) }
        nonmutating set { defaults.set(newValue.map(\.rawValue), forKey: Self.favoriteExercisesKey) }
    }

    /// The whole profile at once.
    var onboardingProfile: OnboardingProfile {
        OnboardingProfile(goal: trainingGoal, level: trainingLevel,
                          favoriteExercises: favoriteExercises, speaksLive: speaksLive)
    }

    /// Writes every answer, marks the onboarding done, and makes the first favorite the chosen exercise.
    func apply(_ profile: OnboardingProfile) {
        trainingGoal = profile.goal
        trainingLevel = profile.level
        favoriteExercises = profile.favoriteExercises
        speaksLive = profile.speaksLive
        if let first = profile.favoriteExercises.first { selectedExercise = first }
        onboardingCompleted = true
    }

    /// The order of the exercise chips on the first screen.
    var exerciseOrder: [ExerciseKind] { onboardingProfile.exerciseOrder }
}
