import Foundation
import Testing
@testable import Finn

struct OnboardingProfileTests {
    @Test func oldSettingsMoveToFinnWithoutOverwritingNewChoices() {
        let suite = "FinnMigration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "plumb.onboardingCompleted")
        defaults.set(false, forKey: "plumb.handsFree")
        defaults.set(true, forKey: FinnPreferences.handsFreeKey)
        let prefs = FinnPreferences(defaults: defaults, handsFreeByDefault: true)
        #expect(prefs.onboardingCompleted)
        #expect(prefs.handsFree)
        #expect(defaults.object(forKey: "plumb.onboardingCompleted") == nil)
        #expect(defaults.object(forKey: "plumb.handsFree") == nil)
    }

    private func preferences() -> FinnPreferences {
        let suite = "OnboardingProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return FinnPreferences(defaults: defaults, handsFreeByDefault: true, remembersExercise: true)
    }

    @Test func freshInstallHasNoAnswersAndShowsTheWelcome() {
        let prefs = preferences()
        #expect(!prefs.onboardingCompleted)
        #expect(prefs.onboardingProfile == OnboardingProfile(goal: nil, level: nil, favouriteExercises: [], speaksLive: true))
        #expect(prefs.exerciseOrder == ExerciseKind.allCases)
        #expect(prefs.onboardingProfile.coachNote == nil)
    }

    @Test func applyingTheAnswersWritesEveryPreference() {
        let prefs = preferences()
        let profile = OnboardingProfile(goal: .muscle, level: .experienced,
                                        favouriteExercises: [.pullUp, .pushUp], speaksLive: false,
                                        firstName: "Alex", followedProgram: true,
                                        stopReasons: [.injury, .motivation], intensity: .challenge,
                                        days: .threeToFour)
        prefs.apply(profile)
        #expect(prefs.onboardingCompleted)
        #expect(prefs.trainingGoal == .muscle)
        #expect(prefs.trainingLevel == .experienced)
        #expect(prefs.firstName == "Alex")
        #expect(prefs.followedProgram == true)
        #expect(prefs.programStopReasons == [.injury, .motivation])
        #expect(prefs.trainingIntensity == .challenge)
        #expect(prefs.trainingDays == .threeToFour)
        #expect(prefs.favouriteExercises == [.pullUp, .pushUp])
        #expect(prefs.speaksLive == false)
        // The first favourite is the exercise ready on the first screen.
        #expect(prefs.selectedExercise == .pullUp)
        #expect(prefs.onboardingProfile == profile)
    }

    @Test func favoritesComeFirstThenTheOthersInTheirUsualOrder() {
        let prefs = preferences()
        prefs.apply(OnboardingProfile(goal: nil, level: nil, favouriteExercises: [.muscleUp, .staticLunge], speaksLive: true))
        #expect(prefs.exerciseOrder == [.muscleUp, .staticLunge, .bodyweightSquat, .pushUp, .stiffLegDeadlift, .pullUp])
        #expect(prefs.exerciseOrder.count == ExerciseKind.allCases.count)
    }

    @Test func skippingEverythingStillCompletesAndChangesNothingElse() {
        let prefs = preferences()
        prefs.selectedExercise = .stiffLegDeadlift
        prefs.apply(OnboardingProfile())
        #expect(prefs.onboardingCompleted)
        #expect(prefs.trainingGoal == nil)
        #expect(prefs.favouriteExercises.isEmpty)
        #expect(prefs.selectedExercise == .stiffLegDeadlift)
        #expect(prefs.speaksLive)
    }

    @Test func unknownStoredExercisesAreDropped() {
        let prefs = preferences()
        prefs.defaults.set(["bodyweightSquat", "handstand"], forKey: FinnPreferences.favouriteExercisesKey)
        #expect(prefs.favouriteExercises == [.bodyweightSquat])
    }

    @Test func coachNoteFollowsLevelAndGoal() {
        let new = OnboardingProfile(goal: .comeback, level: .new)
        let note = new.coachNote ?? ""
        #expect(note.contains("prefer a recent set"))
        #expect(note.contains("prefer the most recent relevant set"))
        let onlyGoal = OnboardingProfile(goal: .technique, level: nil)
        #expect(onlyGoal.coachNote == "Their goal is clearer technique: prefer a set with a recorded form observation when relevant.")
    }

    @Test func accessFinnWaitsForTheSetupAndTheInjuryHistory() {
        var profile = OnboardingProfile(sex: .female, heightCentimeters: 170, weightKilograms: 65)
        #expect(!profile.aboutYouIsComplete)
        profile.location = .gym
        profile.equipment = [.pullUpBar]
        #expect(!profile.aboutYouIsComplete)
        profile.injuries = "   "
        #expect(!profile.aboutYouIsComplete)
        profile.injuries = "Left knee"
        #expect(profile.aboutYouIsComplete)
        profile.injuries = ""
        profile.noPastInjuries = true
        #expect(profile.aboutYouIsComplete)
    }

    @Test func aboutYouAnswersAreSavedAndForgotten() {
        let prefs = preferences()
        let profile = OnboardingProfile(sex: .male, heightCentimeters: 182, weightKilograms: 79.5,
                                        location: .outdoors, equipment: [.none], injuries: " Lower back ")
        prefs.apply(profile)
        #expect(prefs.bodySex == .male)
        #expect(prefs.heightCentimeters == 182)
        #expect(prefs.weightKilograms == 79.5)
        #expect(prefs.trainingLocation == .outdoors)
        #expect(prefs.trainingEquipment == [.none])
        #expect(prefs.pastInjuries == "Lower back")
        #expect(!prefs.noPastInjuries)
        prefs.resetLocalChoices()
        #expect(prefs.bodySex == nil)
        #expect(prefs.heightCentimeters == nil)
        #expect(prefs.weightKilograms == nil)
        #expect(prefs.trainingLocation == nil)
        #expect(prefs.trainingEquipment.isEmpty)
        #expect(prefs.pastInjuries.isEmpty)
    }

    @Test func buildMuscleKeepsTheStoredValueOfGetStronger() {
        let prefs = preferences()
        prefs.defaults.set("strength", forKey: FinnPreferences.trainingGoalKey)
        #expect(prefs.trainingGoal == .muscle)
    }

    @Test func theNameIsTrimmedAndOnlyYesKeepsStopReasons() {
        let prefs = preferences()
        let profile = OnboardingProfile(firstName: "  Zoé-Anne ", followedProgram: false, stopReasons: [.injury])
        #expect(profile.preferredName == "Zoé-Anne")
        #expect(OnboardingProfile(firstName: "   ").preferredName == nil)
        prefs.apply(profile)
        #expect(prefs.firstName == "Zoé-Anne")
        #expect(prefs.followedProgram == false)
        #expect(prefs.programStopReasons.isEmpty)
    }

    @Test func deletingLocalDataForgetsOnboardingAndHealthChoices() {
        let prefs = preferences()
        prefs.apply(OnboardingProfile(goal: .comeback, level: .regular,
                                      favouriteExercises: [.pushUp], speaksLive: false,
                                      firstName: "Alex", followedProgram: true, stopReasons: [.didNotWork],
                                      intensity: .hard, days: .fivePlus))
        prefs.personalisesWithHealth = true
        prefs.savesToFitness = true
        prefs.hapticFeedback = .regular
        prefs.soundFeedback = .bright
        prefs.resetLocalChoices()
        #expect(!prefs.onboardingCompleted)
        #expect(prefs.trainingGoal == nil)
        #expect(prefs.trainingLevel == nil)
        #expect(prefs.favouriteExercises.isEmpty)
        #expect(prefs.firstName.isEmpty)
        #expect(prefs.followedProgram == nil)
        #expect(prefs.programStopReasons.isEmpty)
        #expect(prefs.trainingIntensity == nil)
        #expect(prefs.trainingDays == nil)
        #expect(prefs.selectedExercise == nil)
        #expect(prefs.speaksLive)
        #expect(!prefs.personalisesWithHealth)
        #expect(!prefs.savesToFitness)
        #expect(prefs.hapticFeedback == .gentle)
        #expect(prefs.soundFeedback == .off)
    }
}
