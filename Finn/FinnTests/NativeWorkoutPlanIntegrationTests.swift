import FoundationModels
import XCTest
@testable import Finn

/// This opt-in gate requires a genuine model plan. Local fallback never counts as a pass.
final class NativeWorkoutPlanIntegrationTests: XCTestCase {
    @MainActor
    func testAppleIntelligenceCreatesAValidatedPersonalisedWorkout() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FINN_NATIVE_COACH_TESTS"] == "1",
                          "Set TEST_RUNNER_FINN_NATIVE_COACH_TESTS=1 to test real Apple Intelligence.")
        // The prescription schema uses stable exercise identifiers, independent of translated labels.
        // Check every supported app locale against the installed model before requiring a real plan.
        for identifier in ["en-GB", "en-US", "fr", "es"] {
            XCTAssertTrue(SystemLanguageModel.default.supportsLocale(Locale(identifier: identifier)),
                          "The installed model does not support \(identifier).")
        }
        let engine = AppleWorkoutPlanEngine()
        XCTAssertTrue(engine.available, "The opted-in test requires installed Apple Intelligence assets.")
        guard engine.available else { return }
        let profile = OnboardingProfile(goal: .technique, level: .returning, intensity: .easy,
                                        days: .oneToTwo, equipment: [.none], noPastInjuries: true)
        let context = WorkoutPlanningContext(profile: profile, history: [],
                                            health: HealthSnapshot(sleepLastNight: 4 * 3_600), healthEnabled: true)
        let baseline = PersonalisedWorkoutRules.make(context: context)
        let planner = PersonalisedWorkoutPlanner(engine: engine, timeout: .seconds(30))
        let result = await planner.make(context: context)
        XCTAssertEqual(result.planningSource, .appleIntelligence, "A local fallback is not a model pass.")
        XCTAssertEqual(Set(result.exercises.map(\.exercise)), Set(baseline.exercises.map(\.exercise)))
        for exercise in result.exercises {
            let ceiling = try XCTUnwrap(baseline.exercises.first { $0.exercise == exercise.exercise })
            XCTAssertTrue((1...ceiling.sets).contains(exercise.sets))
            XCTAssertTrue((1...ceiling.reps).contains(exercise.reps))
        }
        XCTAssertFalse(result.exercises.contains { $0.exercise == .pullUp || $0.exercise == .muscleUp })
    }
}
