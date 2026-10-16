import Foundation

/// what the person wants from Finn, asked once at the first launch
nonisolated enum TrainingGoal: String, Codable, CaseIterable, Sendable {
    case technique
    case consistency
    /// stored as "strength", its value before "Get stronger" became "Build muscle"
    case muscle = "strength"
    case comeback
    case fatLoss

    var title: String {
        switch self {
        case .technique: String(localized: "Clearer technique")
        case .consistency: String(localized: "Train more regularly")
        case .muscle: String(localized: "Build muscle")
        case .comeback: String(localized: "Come back after a break")
        case .fatLoss: String(localized: "Lose fat")
        }
    }

    var symbol: String {
        switch self {
        case .technique: "scope"
        case .consistency: "calendar"
        case .muscle: "figure.strengthtraining.traditional"
        case .comeback: "arrow.uturn.forward"
        case .fatLoss: "flame"
        }
    }

    /// what Finn says once Continue is tapped
    var finnLine: String {
        switch self {
        case .technique: String(localized: "Form first. I'll catch what you can't see.")
        case .consistency: String(localized: "Little and often. I'll keep you on track.")
        case .muscle: String(localized: "Let's build it right. I'll make every rep count.")
        case .comeback: String(localized: "Welcome back. We'll ease in and build from there.")
        case .fatLoss: String(localized: "Let's keep you moving. Every set counts.")
        }
    }
}

/// how used to training the person is. Helps the coach select relevant saved sets;
/// it never changes what Finn measures
nonisolated enum TrainingLevel: String, Codable, CaseIterable, Sendable {
    case new
    case returning
    case regular
    case experienced

    var title: String {
        switch self {
        case .new: String(localized: "I've never really trained")
        case .returning: String(localized: "Coming back after a break")
        case .regular: String(localized: "I train regularly")
        case .experienced: String(localized: "I'm advanced")
        }
    }

    var finnLine: String {
        switch self {
        case .new: String(localized: "Everyone starts somewhere. I'll guide each move.")
        case .returning: String(localized: "Good to have you back. We'll find your rhythm again.")
        case .regular: String(localized: "Then let's sharpen your form and push further.")
        case .experienced: String(localized: "Then I'll focus on the details that make a difference.")
        }
    }
}

/// why a past training programme ended. Several can apply
nonisolated enum ProgramStopReason: String, Codable, CaseIterable, Sendable {
    case motivation
    case injury
    case didNotWork

    var title: String {
        switch self {
        case .motivation: String(localized: "I lost motivation")
        case .injury: String(localized: "I got injured")
        case .didNotWork: String(localized: "The program didn't work for me")
        }
    }
}

/// how hard the person wants Finn to push
nonisolated enum TrainingIntensity: String, Codable, CaseIterable, Sendable {
    case easy
    case challenge
    case hard
    case finnDecides

    var title: String {
        switch self {
        case .easy: String(localized: "Go easy on me")
        case .challenge: String(localized: "Challenge me")
        case .hard: String(localized: "Push me hard")
        case .finnDecides: String(localized: "You decide")
        }
    }

    var finnLine: String {
        switch self {
        case .easy: String(localized: "Steady it is. We'll build up at your pace.")
        case .challenge: String(localized: "Hard but doable. That's where you grow.")
        case .hard: String(localized: "Then I won't let you coast.")
        case .finnDecides: String(localized: "Leave it to me. I'll adjust as you go.")
        }
    }
}

/// how many days a week the person is ready to train
nonisolated enum TrainingDays: String, Codable, CaseIterable, Sendable {
    case oneToTwo
    case threeToFour
    case fivePlus

    var title: String {
        switch self {
        case .oneToTwo: String(localized: "1–2 days")
        case .threeToFour: String(localized: "3–4 days")
        case .fivePlus: String(localized: "5+ days")
        }
    }

    var finnLine: String {
        switch self {
        case .oneToTwo: String(localized: "Short weeks still count. We'll make each session matter.")
        case .threeToFour: String(localized: "We'll build a routine that works for you.")
        case .fivePlus: String(localized: "Big weeks. I'll make sure you recover too.")
        }
    }
}

/// asked after the plan offer, or imported from Apple Health
nonisolated enum BodySex: String, Codable, CaseIterable, Sendable {
    case female, male

    var title: String {
        switch self {
        case .female: String(localized: "Female")
        case .male: String(localized: "Male")
        }
    }
}

nonisolated enum TrainingLocation: String, Codable, CaseIterable, Sendable {
    case gym, home, outdoors

    var title: String {
        switch self {
        case .gym: String(localized: "Gym")
        case .home: String(localized: "Home")
        case .outdoors: String(localized: "Outdoors")
        }
    }
}

/// what the person can train with. "None" excludes the others
nonisolated enum TrainingEquipment: String, Codable, CaseIterable, Sendable {
    case none, pullUpBar, dumbbells, barbell, resistanceBands

    var title: String {
        switch self {
        case .none: String(localized: "None, bodyweight only")
        case .pullUpBar: String(localized: "Pull-up bar")
        case .dumbbells: String(localized: "Dumbbells")
        case .barbell: String(localized: "Barbell")
        case .resistanceBands: String(localized: "Resistance bands")
        }
    }
}

/// the answers of the first launch, read from and written to `FinnPreferences`
nonisolated struct OnboardingProfile: Equatable, Sendable {
    var goal: TrainingGoal?
    var level: TrainingLevel?
    /// exercises the person picked, in the order of the picker. Empty means no preference.
    var favoriteExercises: [ExerciseKind] = []
    var speaksLive = true
    /// as typed; `preferredName` is the trimmed value the screens use
    var firstName = ""
    var followedProgram: Bool?
    /// only meaningful when `followedProgram` is true
    var stopReasons: [ProgramStopReason] = []
    var intensity: TrainingIntensity?
    var days: TrainingDays?
    var sex: BodySex?
    var heightCentimeters: Int?
    var weightKilograms: Double?
    var location: TrainingLocation?
    var equipment: [TrainingEquipment] = []
    var injuries = ""
    var noPastInjuries = false

    /// Access Finn waits for the training setup and the injury history; sex, height and weight are optional
    var aboutYouIsComplete: Bool {
        location != nil && !equipment.isEmpty
            && (noPastInjuries || !injuries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// the first name without surrounding spaces, nil when there is none
    var preferredName: String? {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// the exercises in the order the first screen shows them: favourites first, then the rest
    var exerciseOrder: [ExerciseKind] {
        favoriteExercises + ExerciseKind.allCases.filter { !favoriteExercises.contains($0) }
    }

    /// selection hints added to the coach prompt. The model still returns set labels only.
    var coachNote: String? {
        var parts: [String] = []
        switch level {
        case .new?: parts.append("The person is new to training: prefer a recent set with one clear recorded observation.")
        case .returning?: parts.append("The person is coming back after a break: prefer the most recent relevant set.")
        case .regular?: parts.append("The person trains regularly: prefer a set with a recorded comparison when relevant.")
        case .experienced?: parts.append("The person is advanced: prefer sets with measured counts or comparisons when relevant.")
        case nil: break
        }
        switch goal {
        case .technique?: parts.append("Their goal is clearer technique: prefer a set with a recorded form observation when relevant.")
        case .consistency?: parts.append("Their goal is to train more regularly: prefer recent dated sets when relevant.")
        case .muscle?: parts.append("Their goal is to build muscle: prefer sets with recorded rep counts or comparisons when relevant.")
        case .comeback?: parts.append("They are coming back after a break: prefer the most recent relevant set.")
        case .fatLoss?: parts.append("Their goal is to lose fat: prefer recent dated sets when relevant.")
        case nil: break
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

extension FinnPreferences {
    static let onboardingCompletedKey = "finn.onboardingCompleted"
    static let trainingGoalKey = "finn.trainingGoal"
    static let trainingLevelKey = "finn.trainingLevel"
    static let favoriteExercisesKey = "finn.favoriteExercises"
    static let firstNameKey = "finn.firstName"
    static let followedProgramKey = "finn.followedProgram"
    static let programStopReasonsKey = "finn.programStopReasons"
    static let trainingIntensityKey = "finn.trainingIntensity"
    static let trainingDaysKey = "finn.trainingDays"
    static let bodySexKey = "finn.bodySex"
    static let heightCentimetersKey = "finn.heightCentimeters"
    static let weightKilogramsKey = "finn.weightKilograms"
    static let trainingLocationKey = "finn.trainingLocation"
    static let trainingEquipmentKey = "finn.trainingEquipment"
    static let pastInjuriesKey = "finn.pastInjuries"
    static let noPastInjuriesKey = "finn.noPastInjuries"

    /// true once the person finished or skipped the first-launch screens
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

    /// the exercises picked at the first launch, in order. Unknown values from a later build are dropped.
    var favoriteExercises: [ExerciseKind] {
        get { (defaults.stringArray(forKey: Self.favoriteExercisesKey) ?? []).compactMap(ExerciseKind.init(rawValue:)) }
        nonmutating set { defaults.set(newValue.map(\.rawValue), forKey: Self.favoriteExercisesKey) }
    }

    var firstName: String {
        get { defaults.string(forKey: Self.firstNameKey) ?? "" }
        nonmutating set { defaults.set(newValue.isEmpty ? nil : newValue, forKey: Self.firstNameKey) }
    }

    /// nil until answered
    var followedProgram: Bool? {
        get { defaults.object(forKey: Self.followedProgramKey) as? Bool }
        nonmutating set { defaults.set(newValue, forKey: Self.followedProgramKey) }
    }

    var programStopReasons: [ProgramStopReason] {
        get { (defaults.stringArray(forKey: Self.programStopReasonsKey) ?? []).compactMap(ProgramStopReason.init(rawValue:)) }
        nonmutating set { defaults.set(newValue.isEmpty ? nil : newValue.map(\.rawValue), forKey: Self.programStopReasonsKey) }
    }

    var trainingIntensity: TrainingIntensity? {
        get { defaults.string(forKey: Self.trainingIntensityKey).flatMap(TrainingIntensity.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.trainingIntensityKey) }
    }

    var trainingDays: TrainingDays? {
        get { defaults.string(forKey: Self.trainingDaysKey).flatMap(TrainingDays.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.trainingDaysKey) }
    }

    var bodySex: BodySex? {
        get { defaults.string(forKey: Self.bodySexKey).flatMap(BodySex.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.bodySexKey) }
    }

    var heightCentimeters: Int? {
        get { defaults.object(forKey: Self.heightCentimetersKey) as? Int }
        nonmutating set { defaults.set(newValue, forKey: Self.heightCentimetersKey) }
    }

    var weightKilograms: Double? {
        get { defaults.object(forKey: Self.weightKilogramsKey) as? Double }
        nonmutating set { defaults.set(newValue, forKey: Self.weightKilogramsKey) }
    }

    var trainingLocation: TrainingLocation? {
        get { defaults.string(forKey: Self.trainingLocationKey).flatMap(TrainingLocation.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.trainingLocationKey) }
    }

    var trainingEquipment: [TrainingEquipment] {
        get { (defaults.stringArray(forKey: Self.trainingEquipmentKey) ?? []).compactMap(TrainingEquipment.init(rawValue:)) }
        nonmutating set { defaults.set(newValue.isEmpty ? nil : newValue.map(\.rawValue), forKey: Self.trainingEquipmentKey) }
    }

    var pastInjuries: String {
        get { defaults.string(forKey: Self.pastInjuriesKey) ?? "" }
        nonmutating set { defaults.set(newValue.isEmpty ? nil : newValue, forKey: Self.pastInjuriesKey) }
    }

    var noPastInjuries: Bool {
        get { defaults.bool(forKey: Self.noPastInjuriesKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.noPastInjuriesKey) }
    }

    /// the whole profile at once
    var onboardingProfile: OnboardingProfile {
        OnboardingProfile(goal: trainingGoal, level: trainingLevel,
                          favoriteExercises: favoriteExercises, speaksLive: speaksLive,
                          firstName: firstName, followedProgram: followedProgram,
                          stopReasons: programStopReasons, intensity: trainingIntensity, days: trainingDays,
                          sex: bodySex, heightCentimeters: heightCentimeters, weightKilograms: weightKilograms,
                          location: trainingLocation, equipment: trainingEquipment,
                          injuries: pastInjuries, noPastInjuries: noPastInjuries)
    }

    /// writes every answer, marks the onboarding done, and makes the first favourite the chosen exercise
    func apply(_ profile: OnboardingProfile) {
        trainingGoal = profile.goal
        trainingLevel = profile.level
        favoriteExercises = profile.favoriteExercises
        speaksLive = profile.speaksLive
        firstName = profile.preferredName ?? ""
        followedProgram = profile.followedProgram
        programStopReasons = profile.followedProgram == true ? profile.stopReasons : []
        trainingIntensity = profile.intensity
        trainingDays = profile.days
        bodySex = profile.sex
        heightCentimeters = profile.heightCentimeters
        weightKilograms = profile.weightKilograms
        trainingLocation = profile.location
        trainingEquipment = profile.equipment
        pastInjuries = profile.noPastInjuries ? "" : profile.injuries.trimmingCharacters(in: .whitespacesAndNewlines)
        noPastInjuries = profile.noPastInjuries
        if let first = profile.favoriteExercises.first { selectedExercise = first }
        onboardingCompleted = true
    }

    /// the order of the exercise chips on the first screen
    var exerciseOrder: [ExerciseKind] { onboardingProfile.exerciseOrder }

    /// erases Finn's saved choices when the person deletes all local app data. HealthKit grants
    /// live in iOS and must still be managed in Health settings
    func resetLocalChoices() {
        for key in [Self.onboardingCompletedKey, Self.trainingGoalKey, Self.trainingLevelKey,
                    Self.favoriteExercisesKey, Self.firstNameKey, Self.followedProgramKey,
                    Self.programStopReasonsKey, Self.trainingIntensityKey, Self.trainingDaysKey,
                    Self.bodySexKey, Self.heightCentimetersKey, Self.weightKilogramsKey,
                    Self.trainingLocationKey, Self.trainingEquipmentKey, Self.pastInjuriesKey,
                    Self.noPastInjuriesKey,
                    Self.recognizesExerciseKey, Self.usesTrainedModelKey,
                    Self.checksCameraAngleKey, Self.handsFreeKey, Self.speaksLiveKey,
                    Self.savesToFitnessKey, Self.selectedExerciseKey,
                    Self.personalizesWithHealthKey, Self.personalizationOfferedKey,
                    Self.hapticFeedbackKey, Self.soundFeedbackKey] {
            defaults.removeObject(forKey: key)
        }
    }
}
