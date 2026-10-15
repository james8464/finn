import Foundation
import Testing
@testable import Plumb

struct OnboardingProfileTests {
    private func preferences() -> PlumbPreferences {
        let suite = "OnboardingProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return PlumbPreferences(defaults: defaults, handsFreeByDefault: true, remembersExercise: true)
    }

    @Test func freshInstallHasNoAnswersAndShowsTheWelcome() {
        let prefs = preferences()
        #expect(!prefs.onboardingCompleted)
        #expect(prefs.onboardingProfile == OnboardingProfile(goal: nil, level: nil, favoriteExercises: [], speaksLive: true))
        #expect(prefs.exerciseOrder == ExerciseKind.allCases)
        #expect(prefs.onboardingProfile.coachNote == nil)
    }

    @Test func applyingTheAnswersWritesEveryPreference() {
        let prefs = preferences()
        let profile = OnboardingProfile(goal: .strength, level: .experienced,
                                        favoriteExercises: [.pullUp, .pushUp], speaksLive: false)
        prefs.apply(profile)
        #expect(prefs.onboardingCompleted)
        #expect(prefs.trainingGoal == .strength)
        #expect(prefs.trainingLevel == .experienced)
        #expect(prefs.favoriteExercises == [.pullUp, .pushUp])
        #expect(prefs.speaksLive == false)
        // The first favorite is the exercise ready on the first screen.
        #expect(prefs.selectedExercise == .pullUp)
        #expect(prefs.onboardingProfile == profile)
    }

    @Test func favoritesComeFirstThenTheOthersInTheirUsualOrder() {
        let prefs = preferences()
        prefs.apply(OnboardingProfile(goal: nil, level: nil, favoriteExercises: [.muscleUp, .staticLunge], speaksLive: true))
        #expect(prefs.exerciseOrder == [.muscleUp, .staticLunge, .bodyweightSquat, .pushUp, .stiffLegDeadlift, .pullUp])
        #expect(prefs.exerciseOrder.count == ExerciseKind.allCases.count)
    }

    @Test func skippingEverythingStillCompletesAndChangesNothingElse() {
        let prefs = preferences()
        prefs.selectedExercise = .stiffLegDeadlift
        prefs.apply(OnboardingProfile())
        #expect(prefs.onboardingCompleted)
        #expect(prefs.trainingGoal == nil)
        #expect(prefs.favoriteExercises.isEmpty)
        #expect(prefs.selectedExercise == .stiffLegDeadlift)
        #expect(prefs.speaksLive)
    }

    @Test func unknownStoredExercisesAreDropped() {
        let prefs = preferences()
        prefs.defaults.set(["bodyweightSquat", "handstand"], forKey: PlumbPreferences.favoriteExercisesKey)
        #expect(prefs.favoriteExercises == [.bodyweightSquat])
    }

    @Test func coachNoteFollowsLevelAndGoal() {
        let new = OnboardingProfile(goal: .comeback, level: .new)
        let note = new.coachNote ?? ""
        #expect(note.contains("prefer a recent set"))
        #expect(note.contains("prefer the most recent relevant set"))
        let onlyGoal = OnboardingProfile(goal: .technique, level: nil)
        #expect(onlyGoal.coachNote == "Their goal is cleaner technique: prefer a set with a recorded form observation when relevant.")
    }

    @Test func deletingLocalDataForgetsOnboardingAndHealthChoices() {
        let prefs = preferences()
        prefs.apply(OnboardingProfile(goal: .comeback, level: .regular,
                                      favoriteExercises: [.pushUp], speaksLive: false))
        prefs.personalizesWithHealth = true
        prefs.savesToFitness = true
        prefs.resetLocalChoices()
        #expect(!prefs.onboardingCompleted)
        #expect(prefs.trainingGoal == nil)
        #expect(prefs.trainingLevel == nil)
        #expect(prefs.favoriteExercises.isEmpty)
        #expect(prefs.selectedExercise == nil)
        #expect(prefs.speaksLive)
        #expect(!prefs.personalizesWithHealth)
        #expect(!prefs.savesToFitness)
    }
}
