import Testing
@testable import Finn

@MainActor
struct TryFinnTests {
    @Test func eachLevelGetsItsExercise() {
        #expect(TryFinnLevel(.new) == .beginner)
        #expect(TryFinnLevel(.regular) == .intermediate)
        #expect(TryFinnLevel(.experienced) == .advanced)
        // no answer, and the onboarding's "returning" (unknown on older builds), start as beginner
        #expect(TryFinnLevel(nil) == .beginner)
        #expect(TryFinnLevel(TrainingLevel(rawValue: "returning")) == .beginner)

        #expect(TryFinnExercise.forLevel(.beginner).kind == .bodyweightSquat)
        #expect(TryFinnExercise.forLevel(.intermediate).kind == .staticLunge)
        #expect(TryFinnExercise.forLevel(.advanced).kind == .pushUp)
        for level in TryFinnLevel.allCases {
            let exercise = TryFinnExercise.forLevel(level)
            #expect(exercise.level == level)
            #expect(exercise.reps > 0)
            #expect(!exercise.name.isEmpty)
            #expect(exercise.formSteps == PostureGuideSteps.forExercise(exercise.kind))
        }
    }

    @Test func allowedCameraOpensAtOnce() async {
        let model = TryFinnViewModel(level: .new, camera: .fixed(.authorized))
        #expect(await model.tryExercise())
        #expect(model.blockedAccess == nil)
    }

    /// iOS asks only when Try exercise is tapped; a refusal explains, and allowing the camera in
    /// Settings brings Try exercise back
    @Test func cameraIsAskedForOnTryExerciseOnly() async {
        let camera = PromptRecorder(answer: false)
        let model = TryFinnViewModel(level: .regular, camera: camera.access)
        #expect(model.exercise.kind == .staticLunge)
        #expect(camera.asked == 0)

        #expect(await model.tryExercise() == false)
        #expect(camera.asked == 1)
        #expect(model.blockedAccess == .denied)

        camera.status = .authorized
        model.refreshAccess()
        #expect(model.blockedAccess == nil)
        #expect(await model.tryExercise())
        #expect(camera.asked == 1)
    }

    @Test func restrictedCameraIsExplainedWithoutAsking() async {
        let model = TryFinnViewModel(level: .experienced, camera: .fixed(.restricted))
        #expect(await model.tryExercise() == false)
        #expect(model.blockedAccess == .restricted)
        // still restricted on return from Settings: the explanation stays
        model.refreshAccess()
        #expect(model.blockedAccess == .restricted)
    }
}

/// Try Finn on the Watch: the target travels with the set, and the wrist taps once per rep, then
/// a success at the target. Ordinary sets and saved states never tap
nonisolated struct TryFinnWatchTests {
    @Test func targetRoundTripsAndOlderMessagesHaveNone() {
        let state = WatchState(stage: .capturing, exercise: "Squat", reps: 3, target: 8, setID: "set")
        #expect(WatchState(message: state.message())?.target == 8)
        var older = state.message()
        older.removeValue(forKey: WatchMessageKey.target)
        #expect(WatchState(message: older)?.target == nil)
    }

    @Test func wristTapsEachRepThenSucceedsAtTheTarget() {
        func state(_ reps: Int, target: Int? = 8, stage: WatchStage = .capturing, set: String = "set",
                   haptics: Bool = true) -> WatchState {
            WatchState(stage: stage, reps: reps, target: target, setID: set, hapticsEnabled: haptics)
        }
        #expect(WatchTargetTaps.haptic(after: state(2), for: state(3)) == .rep)
        #expect(WatchTargetTaps.haptic(after: state(7), for: state(8)) == .end)
        #expect(WatchTargetTaps.haptic(after: state(7), for: state(8, stage: .analyzing)) == .end)
        #expect(WatchTargetTaps.haptic(after: state(3), for: state(3)) == .none)
        #expect(WatchTargetTaps.haptic(after: nil, for: state(3)) == .none)
        #expect(WatchTargetTaps.haptic(after: state(3, set: "old"), for: state(4)) == .none)
        #expect(WatchTargetTaps.haptic(after: state(2, target: nil), for: state(3, target: nil)) == .none)
        #expect(WatchTargetTaps.haptic(after: state(2, haptics: false), for: state(3, haptics: false)) == .none)
    }
}

/// a camera that has not been asked yet, and how many times iOS showed its prompt
@MainActor
private final class PromptRecorder {
    var status = TryFinnCameraAccess.Status.notDetermined
    private(set) var asked = 0
    private let answer: Bool

    init(answer: Bool) { self.answer = answer }

    var access: TryFinnCameraAccess {
        TryFinnCameraAccess(status: { self.status }, request: {
            self.asked += 1
            self.status = self.answer ? .authorized : .denied
            return self.answer
        })
    }
}
