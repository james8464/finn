import Foundation
import Testing
@testable import Plumb

nonisolated struct FitnessWorkoutTests {
    private let origin = Date(timeIntervalSince1970: 1_800_000_000)

    /// A set saved `secondsIn` after `origin`, with `reps` reps of 2 s each, 1 s apart, on the
    /// capture clock starting at `clockStart` (the camera's clock, not the date).
    private func set(_ exercise: ExerciseKind = .bodyweightSquat, reps: Int, secondsIn: TimeInterval,
                     clockStart: TimeInterval = 5_000) -> SetSummary {
        let metrics = (0..<reps).map { index in
            RepMetric(number: index + 1, startTime: clockStart + Double(index) * 3,
                      endTime: clockStart + Double(index) * 3 + 2, relativeRange: 0.4)
        }
        return SetSummary(id: UUID(), sessionID: UUID(), capturedAt: origin.addingTimeInterval(secondsIn),
                          bodySide: .left,
                          analysis: SetAnalysis(reps: metrics, confidence: 0.9, rubricVersion: "test"),
                          cue: nil, cueResponse: .unanswered, exercise: exercise)
    }

    private func session(_ sets: [SetSummary]) -> WorkoutSessionSummary {
        WorkoutSessionSummary(id: UUID(), startedAt: origin, sets: sets)
    }

    @Test func aSessionWithNoMeasuredSetIsNotSaved() {
        #expect(FitnessWorkout.make(from: session([])) == nil)
        #expect(FitnessWorkout.make(from: session([set(reps: 0, secondsIn: 60)])) == nil)
    }

    /// Six reps span 17 s on the capture clock (0 to 17); the set ended when it was saved.
    @Test func theWorkoutRunsFromTheFirstMeasuredRepToTheEndOfTheLastSet() throws {
        let sessionValue = session([set(reps: 6, secondsIn: 60), set(reps: 4, secondsIn: 200, clockStart: 90_000)])
        let workout = try #require(FitnessWorkout.make(from: sessionValue))
        #expect(workout.sessionID == sessionValue.id)
        #expect(workout.start == origin.addingTimeInterval(60 - 17))
        #expect(workout.end == origin.addingTimeInterval(200))
        #expect(workout.pauses.isEmpty)
        #expect(workout.activeDuration == 157)
    }

    @Test func setsAreOrderedByWhenTheyWereSaved() throws {
        let workout = try #require(FitnessWorkout.make(from: session([
            set(reps: 3, secondsIn: 300), set(reps: 3, secondsIn: 100),
        ])))
        #expect(workout.start == origin.addingTimeInterval(100 - 8))
        #expect(workout.end == origin.addingTimeInterval(300))
    }

    /// The person left the app open for an hour between two sets: five minutes of rest count,
    /// the rest of the break is paused so it does not count as workout time.
    @Test func aLongBreakBetweenSetsIsPaused() throws {
        let workout = try #require(FitnessWorkout.make(from: session([
            set(reps: 6, secondsIn: 60), set(reps: 6, secondsIn: 3_660),
        ])))
        let pause = try #require(workout.pauses.first)
        #expect(workout.pauses.count == 1)
        #expect(pause.start == origin.addingTimeInterval(60 + FitnessWorkout.longestRest))
        #expect(pause.end == origin.addingTimeInterval(3_660 - 17))
        #expect(workout.activeDuration == 17 + FitnessWorkout.longestRest + 17)
    }

    @Test func aRestUpToFiveMinutesCountsAsWorkoutTime() throws {
        let workout = try #require(FitnessWorkout.make(from: session([
            set(reps: 6, secondsIn: 0), set(reps: 6, secondsIn: 17 + FitnessWorkout.longestRest),
        ])))
        #expect(workout.pauses.isEmpty)
    }

    @Test func aRepSpanBeyondTheCaptureLimitIsClamped() throws {
        let broken = SetSummary(
            id: UUID(), sessionID: UUID(), capturedAt: origin, bodySide: .left,
            analysis: SetAnalysis(reps: [RepMetric(number: 1, startTime: 0, endTime: 2, relativeRange: 0.4),
                                         RepMetric(number: 2, startTime: 9_998, endTime: 10_000, relativeRange: 0.4)],
                                  confidence: 0.9, rubricVersion: "test"),
            cue: nil, cueResponse: .unanswered)
        let workout = try #require(FitnessWorkout.make(from: session([broken])))
        #expect(workout.start == origin.addingTimeInterval(-FitnessWorkout.longestSet))
    }

    @Test func aSetWithoutAUsableSpanAloneMakesNoWorkout() {
        let still = SetSummary(
            id: UUID(), sessionID: UUID(), capturedAt: origin, bodySide: .left,
            analysis: SetAnalysis(reps: [RepMetric(number: 1, startTime: 4, endTime: 4, relativeRange: 0.4)],
                                  confidence: 0.9, rubricVersion: "test"),
            cue: nil, cueResponse: .unanswered)
        #expect(FitnessWorkout.make(from: session([still])) == nil)
    }

    @Test func everyExerciseIsFunctionalStrengthTraining() throws {
        for kind in ExerciseKind.allCases {
            #expect(kind.fitnessActivity == .functionalStrengthTraining)
        }
        let workout = try #require(FitnessWorkout.make(from: session([
            set(.pushUp, reps: 5, secondsIn: 60), set(.stiffLegDeadlift, reps: 5, secondsIn: 180),
        ])))
        #expect(workout.activity == .functionalStrengthTraining)
        #expect(workout.isIndoor)
    }

    @Test func metadataCountsMeasuredSetsRepsAndNamesEachExerciseOnce() throws {
        let workout = try #require(FitnessWorkout.make(from: session([
            set(.bodyweightSquat, reps: 6, secondsIn: 60),
            set(.pushUp, reps: 0, secondsIn: 120),
            set(.pushUp, reps: 8, secondsIn: 180),
            set(.bodyweightSquat, reps: 5, secondsIn: 300),
        ])))
        #expect(workout.setCount == 3)
        #expect(workout.measuredReps == 19)
        #expect(workout.exerciseNames == ["Squat", "Push-up"])
        #expect(workout.plumbMetadata == [
            "PlumbSetCount": .number(3),
            "PlumbMeasuredReps": .number(19),
            "PlumbExercises": .text("Squat, Push-up"),
        ])
    }

    /// Plumb measures neither energy nor heart rate: its own metadata holds only its three keys.
    @Test func metadataHasNoEnergyOrHeartRate() throws {
        let workout = try #require(FitnessWorkout.make(from: session([set(reps: 6, secondsIn: 60)])))
        #expect(Set(workout.plumbMetadata.keys) == ["PlumbSetCount", "PlumbMeasuredReps", "PlumbExercises"])
        #expect(!workout.plumbMetadata.keys.contains(where: { $0.hasPrefix("HK") }))
    }

    @Test func theSyncIdentifierNamesTheSession() throws {
        let sessionValue = session([set(reps: 6, secondsIn: 60)])
        let workout = try #require(FitnessWorkout.make(from: sessionValue))
        #expect(workout.syncIdentifier == "com.james8464.Plumb.session.\(sessionValue.id.uuidString)")
        #expect(FitnessWorkout.syncVersion == 1)
    }

    @Test func statusLinesAreShortAndPlain() {
        #expect(FitnessSaveStatus.saved.text == "Saved to Fitness")
        #expect(FitnessSaveStatus.failed.text == "Couldn’t save to Fitness")
        #expect(FitnessSaveStatus.needsPermission.text == "Allow Plumb in Health settings")
        #expect(FitnessSaveStatus.failed.offersRetry)
        #expect(!FitnessSaveStatus.saved.offersRetry)
    }

    /// History saved before this feature has no Fitness record and still loads; a record round-trips.
    @Test func savedSessionsDecodeWithAndWithoutAFitnessRecord() throws {
        let id = UUID()
        let old = Data("""
        [{"id":"\(id.uuidString)","startedAt":0,"sets":[]}]
        """.utf8)
        let decoded = try JSONDecoder().decode([WorkoutSessionSummary].self, from: old)
        #expect(decoded.first?.fitnessWorkout == nil)

        var saved = WorkoutSessionSummary(id: id, startedAt: origin, sets: [])
        saved.fitnessWorkout = FitnessWorkoutRecord(savedAt: origin, workoutID: UUID())
        let roundTrip = try JSONDecoder().decode(WorkoutSessionSummary.self, from: JSONEncoder().encode(saved))
        #expect(roundTrip == saved)
        let locked = WorkoutSessionSummary(id: id, startedAt: origin, sets: [],
                                           fitnessWorkout: FitnessWorkoutRecord(savedAt: origin, workoutID: nil))
        #expect(try JSONDecoder().decode(WorkoutSessionSummary.self, from: JSONEncoder().encode(locked)) == locked)
    }

    @Test func theOptionIsOffByDefault() throws {
        let defaults = try #require(UserDefaults(suiteName: "PlumbFitnessPreference-\(UUID())"))
        let preferences = PlumbPreferences(defaults: defaults, handsFreeByDefault: true)
        #expect(!preferences.savesToFitness)
        preferences.savesToFitness = true
        #expect(PlumbPreferences(defaults: defaults).savesToFitness)
    }
}
