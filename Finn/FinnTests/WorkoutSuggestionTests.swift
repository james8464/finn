import Foundation
import Testing
@testable import Finn

@MainActor
struct WorkoutSuggestionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func plan() -> PlannedWorkout {
        PlannedWorkout(exercises: [
            PlannedExercise(exercise: .pushUp, sets: 2, reps: 6),
            PlannedExercise(exercise: .bodyweightSquat, sets: 3, reps: 8)
        ])
    }

    @Test func previewPreservesEveryPrescriptionIdentityAndOrdering() {
        let prescription = plan()
        let preview = NextWorkout.suggestion(from: prescription, profile: OnboardingProfile(), health: nil, now: now)
        #expect(preview.exercises.map(\.id) == prescription.exercises.map(\.id))
        #expect(preview.exercises.map(\.kind) == prescription.exercises.map(\.exercise))
        #expect(preview.exercises.map(\.sets) == prescription.exercises.map(\.sets))
        #expect(preview.exercises.map(\.reps) == prescription.exercises.map(\.reps))
        #expect(preview.start == now)
        #expect(preview.estimatedDuration == Double((2 * 6 + 3 * 8) * 3 + 4 * 90))
        #expect(preview.end == now.addingTimeInterval(preview.estimatedDuration))
    }

    @Test func recoveryAndTechniqueOverrideRequestedHardIntensity() {
        let experienced = OnboardingProfile(level: .experienced, intensity: .hard, noPastInjuries: true)
        let standard = NextWorkout.suggestion(from: plan(), profile: experienced, health: nil, now: now)
        #expect(standard.intensity == .hard)
        let recovering = NextWorkout.suggestion(from: plan(), profile: experienced,
                                               health: HealthSnapshot(sleepLastNight: 3 * 3_600), now: now)
        #expect(recovering.intensity == .light)
        var techniquePlan = plan()
        techniquePlan.exercises[0].focus = "Keep your hips in line"
        #expect(NextWorkout.suggestion(from: techniquePlan, profile: experienced, health: nil, now: now).intensity == .light)
    }

    @Test func beginnerAndEasyPreferencesStayLightWithoutHealthData() {
        for profile in [OnboardingProfile(level: .new), OnboardingProfile(level: .returning),
                        OnboardingProfile(goal: .comeback), OnboardingProfile(intensity: .easy),
                        OnboardingProfile(injuries: "Previous shoulder injury")] {
            #expect(NextWorkout.suggestion(from: plan(), profile: profile, health: nil, now: now).intensity == .light)
        }
        let regular = OnboardingProfile(level: .regular, intensity: .challenge, noPastInjuries: true)
        #expect(NextWorkout.suggestion(from: plan(), profile: regular, health: nil, now: now).intensity == .moderate)
    }
}
