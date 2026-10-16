import Foundation
import Testing
@testable import Finn

@MainActor
struct PersonalisedWorkoutTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func profile(level: TrainingLevel = .regular, equipment: [TrainingEquipment] = [.none]) -> OnboardingProfile {
        OnboardingProfile(goal: .technique, level: level, intensity: .challenge,
                          days: .threeToFour, equipment: equipment, noPastInjuries: true)
    }

    private func history(exercise: ExerciseKind = .pushUp, reps: Int = 10,
                         response: CueResponse = .unanswered, confidence: Double = 0.95,
                         partlyVisible: Bool = false, date: Date? = nil) -> [WorkoutSessionSummary] {
        let sessionID = UUID()
        let sets = (0..<2).map { index in
            SetSummary(id: UUID(), sessionID: sessionID, capturedAt: date ?? now.addingTimeInterval(-Double(index + 1) * 60),
                       bodySide: .left, analysis: SetAnalysis(reps: (1...reps).map {
                           RepMetric(number: $0, startTime: Double($0) * 2, endTime: Double($0) * 2 + 1.5, relativeRange: 0.4)
                       }, confidence: confidence, rubricVersion: "test"), cue: nil,
                       cueResponse: response, exercise: exercise, issues: [.rangeDropped], partlyVisible: partlyVisible)
        }
        return [WorkoutSessionSummary(id: sessionID, startedAt: now.addingTimeInterval(-120), sets: sets)]
    }

    private func plan(profile: OnboardingProfile? = nil, history: [WorkoutSessionSummary] = [],
                      health: HealthSnapshot? = nil, enabled: Bool = false) -> PlannedWorkout {
        PersonalisedWorkoutRules.make(context: WorkoutPlanningContext(profile: profile ?? self.profile(),
            history: history, health: health, healthEnabled: enabled), now: now)
    }

    @Test func bodyweightOnlyAndUnknownEquipmentNeverRequireABar() {
        for equipment: [TrainingEquipment] in [[], [.none], [.none, .pullUpBar]] {
            let workout = plan(profile: profile(level: .experienced, equipment: equipment),
                               history: history(exercise: .pullUp, reps: 15))
            #expect(!workout.exercises.contains { $0.exercise == .pullUp || $0.exercise == .muscleUp })
        }
    }

    @Test func beginnerVolumeAndBarExercisesRemainConservative() {
        let workout = plan(profile: profile(level: .new, equipment: [.pullUpBar]),
                           history: history(exercise: .pullUp, reps: 15))
        #expect(workout.exercises.count == 3)
        #expect(workout.exercises.allSatisfy { $0.sets == 2 })
        #expect(!workout.exercises.contains { $0.exercise == .pullUp || $0.exercise == .muscleUp })
    }

    @Test func favouritesInfluenceOrderWithoutRemovingPushOrLowerBody() {
        var answers = profile()
        answers.favouriteExercises = [.staticLunge]
        let workout = plan(profile: answers)
        #expect(workout.exercises.first?.exercise == .staticLunge)
        #expect(workout.exercises.contains { $0.exercise == .pushUp })
        #expect(workout.exercises.contains { [.bodyweightSquat, .staticLunge, .stiffLegDeadlift].contains($0.exercise) })
    }

    @Test func healthIsAbsentWithoutExplicitConsent() {
        let health = HealthSnapshot(restingHeartRate: 92, restingHeartRateBaseline: 55, sleepLastNight: 3 * 3_600)
        let context = WorkoutPlanningContext(profile: profile(), history: [], health: health)
        #expect(context.health == nil)
        let denied = plan(health: health)
        #expect(denied.exercises.map { [$0.sets, $0.reps] } == plan().exercises.map { [$0.sets, $0.reps] })
        let prompt = PersonalisedWorkoutRules.prompt(context: context, baseline: denied)
        #expect(!prompt.contains("Consented Health"))
        #expect(!prompt.contains("92"))
    }

    @Test func recoveryDataReducesVolumeOnlyWhenEnabled() {
        let health = HealthSnapshot(sleepLastNight: 3 * 3_600)
        let normal = plan()
        let lighter = plan(health: health, enabled: true)
        #expect(normal.exercises.allSatisfy { $0.sets == 3 })
        #expect(lighter.exercises.allSatisfy { $0.sets == 2 })
        #expect(lighter.exercises.reduce(0) { $0 + $1.sets * $1.reps }
                < normal.exercises.reduce(0) { $0 + $1.sets * $1.reps })
        #expect(lighter.planningNote != normal.planningNote)
    }

    @Test func recurringAcceptedTechniqueAddsSpecificFocusAndReducesVolume() throws {
        let workout = plan(history: history())
        let pushUp = try #require(workout.exercises.first { $0.exercise == .pushUp })
        #expect(pushUp.focus == ExerciseDefinition.pushUp.copy.nextAction)
        #expect(pushUp.sets == 2)
        #expect(pushUp.reps == 6)
    }

    @Test func rejectedPartialUncertainAndFutureEvidenceCannotSupplyTechniqueFocus() {
        let unreliable = [history(response: .notRelevant), history(partlyVisible: true),
                          history(confidence: 0.4), history(date: now.addingTimeInterval(60))]
        for saved in unreliable {
            #expect(plan(history: saved).exercises.allSatisfy { $0.focus == nil })
        }
    }

    @Test func untrustedCapacityCannotUnlockMuscleUps() {
        let advanced = profile(level: .experienced, equipment: [.pullUpBar])
        for saved in [history(exercise: .pullUp, reps: 15, confidence: 0.4),
                      history(exercise: .pullUp, reps: 15, partlyVisible: true),
                      history(exercise: .pullUp, reps: 15, date: now.addingTimeInterval(60))] {
            #expect(!plan(profile: advanced, history: saved).exercises.contains { $0.exercise == .muscleUp })
        }
    }

    @Test func recentCapacityWinsOverAnOldPersonalBest() throws {
        let older = history(reps: 20, date: now.addingTimeInterval(-30 * 86_400))
        let recent = history(reps: 5)
        let workout = plan(history: older + recent)
        let pushUp = try #require(workout.exercises.first { $0.exercise == .pushUp })
        #expect(pushUp.reps <= 5)
    }

    @Test func validationRejectsDuplicateMissingUnknownAndUnsafePrescriptions() {
        let baseline = plan()
        let valid = baseline.exercises.map { WorkoutPlanChoice(exercise: $0.exercise, sets: $0.sets, reps: $0.reps) }
        var duplicate = valid
        duplicate[1] = valid[0]
        var unknown = valid
        unknown[0] = WorkoutPlanChoice(exercise: .muscleUp, sets: 1, reps: 1)
        #expect(PersonalisedWorkoutRules.validate(duplicate, against: baseline) == nil)
        #expect(PersonalisedWorkoutRules.validate(Array(valid.dropLast()), against: baseline) == nil)
        #expect(PersonalisedWorkoutRules.validate(unknown, against: baseline) == nil)
        for (sets, reps) in [(0, 1), (1, 0), (-1, 2), (4, 1), (1, 21)] {
            var unsafe = valid
            unsafe[0] = WorkoutPlanChoice(exercise: valid[0].exercise, sets: sets, reps: reps)
            #expect(PersonalisedWorkoutRules.validate(unsafe, against: baseline) == nil)
        }
    }

    @Test func invalidOrDuplicateBaselinePrescriptionsAreRejectedWithoutTrapping() {
        let duplicate = PlannedWorkout(exercises: [
            PlannedExercise(exercise: .pushUp, sets: 2, reps: 6),
            PlannedExercise(exercise: .pushUp, sets: 2, reps: 6)
        ])
        let choices = [WorkoutPlanChoice(exercise: .pushUp, sets: 1, reps: 1),
                       WorkoutPlanChoice(exercise: .bodyweightSquat, sets: 1, reps: 1)]
        #expect(PersonalisedWorkoutRules.validate(choices, against: duplicate) == nil)
        for (sets, reps) in [(0, 1), (1, 0), (4, 1), (1, 21)] {
            let invalid = PlannedWorkout(exercises: [PlannedExercise(exercise: .pushUp, sets: sets, reps: reps)])
            #expect(PersonalisedWorkoutRules.validate([WorkoutPlanChoice(exercise: .pushUp, sets: 1, reps: 1)],
                                                      against: invalid) == nil)
        }
        #expect(PersonalisedWorkoutRules.validate([], against: PlannedWorkout(exercises: [])) == nil)
    }

    @Test func nonFiniteHealthValuesCannotBecomePlanningEvidence() {
        for invalid in [Double.nan, .infinity, -.infinity] {
            let health = HealthSnapshot(restingHeartRate: invalid, restingHeartRateBaseline: invalid,
                                       heartRateVariability: invalid, heartRateVariabilityBaseline: invalid,
                                       vo2Max: invalid, activeEnergyYesterday: invalid, activeEnergyBaseline: invalid,
                                       stepsYesterday: invalid, stepsBaseline: invalid, sleepLastNight: invalid,
                                       weight: invalid, height: invalid)
            let context = WorkoutPlanningContext(profile: profile(), history: [], health: health, healthEnabled: true)
            let workout = PersonalisedWorkoutRules.make(context: context, now: now)
            let prompt = PersonalisedWorkoutRules.prompt(context: context, baseline: workout)
            #expect(!prompt.contains("Consented Health"))
            #expect(!prompt.lowercased().contains("nan"))
            #expect(!prompt.lowercased().contains("infinity"))
            #expect(workout.exercises.allSatisfy { (1...3).contains($0.sets) && (1...20).contains($0.reps) })
        }
    }

    @Test func malformedSavedPlansNeverExposeDuplicateListIdentities() throws {
        let suite = "MalformedPersonalisedPlans.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let valid = plan()
        let repeatedID = UUID()
        let duplicateRows = PlannedWorkout(exercises: [
            PlannedExercise(id: repeatedID, exercise: .pushUp, sets: 2, reps: 6),
            PlannedExercise(id: repeatedID, exercise: .bodyweightSquat, sets: 2, reps: 8)
        ])
        let invalidVolume = PlannedWorkout(exercises: [PlannedExercise(exercise: .pushUp, sets: 100, reps: 100)])
        defaults.set(try JSONEncoder().encode([valid, valid, duplicateRows, invalidVolume]), forKey: "plannedWorkouts.v1")
        let restored = PlannedWorkoutStore(defaults: defaults).upcoming
        #expect(Set(restored.map(\.id)).count == restored.count)
        #expect(restored.contains { $0.id == valid.id })
        #expect(!restored.contains { $0.id == duplicateRows.id || $0.id == invalidVolume.id })
        #expect(restored.allSatisfy { Set($0.exercises.map(\.id)).count == $0.exercises.count })
    }

    @Test func validModelReorderingPreservesRecordedFocusAndProvenance() throws {
        let baseline = plan(history: history())
        let choices = baseline.exercises.reversed().map { WorkoutPlanChoice(exercise: $0.exercise, sets: 1, reps: 1) }
        let result = try #require(PersonalisedWorkoutRules.validate(choices, against: baseline))
        #expect(result.planningSource == .appleIntelligence)
        #expect(result.exercises.map(\.exercise) == choices.map(\.exercise))
        #expect(result.exercises.first { $0.exercise == .pushUp }?.focus
                == baseline.exercises.first { $0.exercise == .pushUp }?.focus)
    }

    @Test func oldSavedPlansWithoutPlanningMetadataStillDecode() throws {
        let original = plan()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "planningSource")
        json.removeValue(forKey: "planningNote")
        let decoded = try JSONDecoder().decode(PlannedWorkout.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.id == original.id)
        #expect(decoded.exercises == original.exercises)
        #expect(decoded.planningSource == nil)
        #expect(decoded.planningNote == nil)
    }

    @Test func unavailableThrowingInvalidAndSlowModelsReturnLocalPlan() async {
        for mode in [PlanningStub.Mode.unavailable, .failure, .invalid, .slow] {
            let engine = PlanningStub(mode: mode)
            let planner = PersonalisedWorkoutPlanner(engine: engine, timeout: .milliseconds(30))
            let result = await planner.make(context: WorkoutPlanningContext(profile: profile(), history: []), now: now)
            #expect(result.planningSource == .localRules)
            #expect(result.exercises.map { [$0.sets, $0.reps] } == plan().exercises.map { [$0.sets, $0.reps] })
            #expect(engine.calls == (mode == .unavailable ? 0 : 1))
        }
    }

    @Test func validEngineOutputUsesModelSource() async {
        let planner = PersonalisedWorkoutPlanner(engine: PlanningStub(mode: .valid))
        let result = await planner.make(context: WorkoutPlanningContext(profile: profile(), history: []), now: now)
        #expect(result.planningSource == .appleIntelligence)
        #expect(result.exercises.allSatisfy { $0.sets == 1 && $0.reps == 1 })
    }
}

@MainActor
private final class PlanningStub: WorkoutPlanGenerating {
    enum Mode { case unavailable, failure, invalid, slow, valid }
    let mode: Mode
    private(set) var calls = 0
    var available: Bool { mode != .unavailable }
    init(mode: Mode) { self.mode = mode }

    func choices(context: WorkoutPlanningContext, baseline: PlannedWorkout) async throws -> [WorkoutPlanChoice] {
        calls += 1
        switch mode {
        case .failure: throw CocoaError(.coderInvalidValue)
        case .slow: try await Task.sleep(for: .seconds(2))
        case .invalid: return []
        default: break
        }
        return baseline.exercises.reversed().map { WorkoutPlanChoice(exercise: $0.exercise, sets: 1, reps: 1) }
    }
}
