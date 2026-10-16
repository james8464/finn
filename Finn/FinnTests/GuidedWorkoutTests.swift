import Foundation
import Testing
@testable import Finn

@MainActor
struct GuidedWorkoutTests {
    private func workout() -> GuidedWorkout {
        GuidedWorkout(plan: PlannedWorkout(exercises: [
            PlannedExercise(exercise: .pushUp, sets: 2, reps: 6),
            PlannedExercise(exercise: .bodyweightSquat, sets: 1, reps: 8)
        ]))
    }

    @Test func manualStagesAdvanceWithoutInventingMeasuredReps() throws {
        var guide = workout()
        let firstStage = try #require(guide.stageID)
        #expect(guide.nextSetNumber == 1)
        let advancedFirstStage = guide.advanceManually(stageID: firstStage)
        #expect(advancedFirstStage)
        let duplicatedFirstStage = guide.advanceManually(stageID: firstStage)
        #expect(!duplicatedFirstStage)
        #expect(guide.nextSetNumber == 2)
        #expect(guide.manualSets == 1)
        #expect(guide.completedSets == 0)
        #expect(guide.progressedSets == 1)
        let advancedSecondStage = guide.advanceManually(stageID: try #require(guide.stageID))
        #expect(advancedSecondStage)
        #expect(guide.next?.exercise == .bodyweightSquat)
        let advancedLastStage = guide.advanceManually(stageID: try #require(guide.stageID))
        #expect(advancedLastStage)
        #expect(guide.isComplete)
        #expect(guide.next == nil)
        #expect(guide.progressedSets == guide.totalSets)
        #expect(guide.recordedSetIDs.isEmpty)
    }

    @Test func measuredCallbacksRejectWrongExerciseNoRepsDuplicatesAndStaleStages() throws {
        var guide = workout()
        let stage = try #require(guide.stageID)
        let setID = UUID()
        let wrongExercise = guide.record(setID: setID, exercise: .bodyweightSquat, measuredReps: 8, expectedStageID: stage)
        #expect(!wrongExercise)
        let emptySet = guide.record(setID: setID, exercise: .pushUp, measuredReps: 0, expectedStageID: stage)
        #expect(!emptySet)
        let measuredSet = guide.record(setID: setID, exercise: .pushUp, measuredReps: 5, expectedStageID: stage)
        #expect(measuredSet)
        let duplicateSet = guide.record(setID: setID, exercise: .pushUp, measuredReps: 5)
        #expect(!duplicateSet)
        let staleStage = guide.record(setID: UUID(), exercise: .pushUp, measuredReps: 5, expectedStageID: stage)
        #expect(!staleStage)
        #expect(guide.completedSets == 1)
        #expect(guide.manualSets == 0)
        #expect(guide.nextSetNumber == 2)
    }

    @Test func mixedManualAndMeasuredProgressRestoresExactlyOnce() throws {
        let suite = "GuidedWorkoutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GuidedWorkoutStore(defaults: defaults)
        var guide = workout()
        let advancedManualStage = guide.advanceManually(stageID: try #require(guide.stageID))
        #expect(advancedManualStage)
        let measuredID = UUID()
        let measuredSet = guide.record(setID: measuredID, exercise: .pushUp, measuredReps: 6)
        #expect(measuredSet)
        store.save(guide)
        var restored = try #require(GuidedWorkoutStore(defaults: defaults).load())
        #expect(restored == guide)
        #expect(restored.manualSets == 1)
        #expect(restored.completedSets == 1)
        #expect(restored.next?.exercise == .bodyweightSquat)
        let duplicateRestoredSet = restored.record(setID: measuredID, exercise: .bodyweightSquat, measuredReps: 8)
        #expect(!duplicateRestoredSet)
        let advancedRestoredStage = restored.advanceManually(stageID: try #require(restored.stageID))
        #expect(advancedRestoredStage)
        store.save(restored)
        #expect(store.load()?.isComplete == true)
        store.save(nil)
        #expect(store.load() == nil)
    }

    @Test func previouslySavedMeasuredWorkoutsDecodeWithoutManualProgress() throws {
        var guide = workout()
        let measuredSet = guide.record(setID: UUID(), exercise: .pushUp, measuredReps: 6)
        #expect(measuredSet)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(guide)) as? [String: Any])
        json.removeValue(forKey: "manualCompleted")
        let restored = try JSONDecoder().decode(GuidedWorkout.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored.completedSets == 1)
        #expect(restored.manualSets == 0)
        #expect(restored.nextSetNumber == 2)
    }

    @Test func corruptAndExcessivePersistedPrescriptionsAreRejected() throws {
        let suite = "GuidedWorkoutInvalidTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GuidedWorkoutStore(defaults: defaults)
        defaults.set(Data("not a workout".utf8), forKey: "guidedWorkout.v1")
        #expect(store.load() == nil)
        store.save(GuidedWorkout(plan: PlannedWorkout(exercises: [PlannedExercise(exercise: .pushUp, sets: 100, reps: 100)])))
        #expect(store.load() == nil)
        defaults.set(Data(repeating: 65, count: 64_001), forKey: "guidedWorkout.v1")
        #expect(store.load() == nil)
    }
}
