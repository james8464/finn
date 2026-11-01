import AVFoundation
import Foundation
import Testing
@testable import Finn

/// One free workout every two weeks without Finn Coach+ (`FreeWorkoutRule`, `WorkoutAccess`)
struct FreeWorkoutRuleTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func days(_ count: Int) -> Date {
        calendar.date(byAdding: .day, value: count, to: start)!
    }

    @Test func theFirstWorkoutIsFree() {
        let rule = FreeWorkoutRule(lastFreeWorkout: nil)
        #expect(rule.allowsFreeWorkout(at: start, calendar: calendar))
        #expect(rule.nextFreeWorkout(calendar: calendar) == nil)
    }

    @Test func theNextFreeWorkoutOpensFourteenDaysLater() {
        let rule = FreeWorkoutRule(lastFreeWorkout: start)
        #expect(!rule.allowsFreeWorkout(at: start.addingTimeInterval(60), calendar: calendar))
        #expect(!rule.allowsFreeWorkout(at: days(13), calendar: calendar))
        #expect(rule.allowsFreeWorkout(at: days(14), calendar: calendar))
        #expect(rule.nextFreeWorkout(calendar: calendar) == days(14))
    }
}

@MainActor
struct FreeWorkoutAccessTests {
    @Test func theStartOfAFreeWorkoutIsKept() throws {
        let defaults = try #require(UserDefaults(suiteName: "FinnFreeWorkout-\(UUID())"))
        let preferences = FinnPreferences(defaults: defaults)
        let access = WorkoutAccess(preferences: preferences, limitsFreeWorkouts: true)
        #expect(access.nextFreeWorkout == nil)
        let now = Date.now
        access.workoutBegan(at: now)
        #expect(preferences.lastFreeWorkout == now)
        #expect(access.nextFreeWorkout != nil)
        // a relaunch reads it back
        let relaunched = WorkoutAccess(preferences: preferences, limitsFreeWorkouts: true)
        #expect(relaunched.rule.lastFreeWorkout == now)
    }

    @Test func demoInputIsNeverLimited() async throws {
        let defaults = try #require(UserDefaults(suiteName: "FinnFreeWorkout-\(UUID())"))
        let preferences = FinnPreferences(defaults: defaults)
        let access = WorkoutAccess(preferences: preferences, limitsFreeWorkouts: false)
        access.workoutBegan(at: .now)
        #expect(preferences.lastFreeWorkout == nil)
        #expect(await access.allowsNewWorkout(at: .now))
    }
}

/// The workout model asks before a new workout, and only then
@MainActor
struct FreeWorkoutSessionTests {
    @Test func aRefusedWorkoutLeavesTheCameraClosed() async throws {
        let setup = try GateSetup(allows: false)
        await setup.model.startPreview()
        #expect(setup.model.freeWorkoutUsed)
        #expect(setup.model.stage == .ready)
        #expect(setup.gate.questions == 1)
    }

    @Test func theSetsOfAnAllowedWorkoutCountOnce() async throws {
        let setup = try GateSetup(allows: true)
        try await setup.measureASet()
        #expect(setup.gate.began == [setup.clock.date])
        #expect(setup.gate.questions == 1)

        // the next set of the same workout: no question, and still one workout
        setup.gate.allows = false
        setup.clock.advance(by: 5 * 60)
        try await setup.measureASet()
        #expect(!setup.model.freeWorkoutUsed)
        #expect(setup.gate.questions == 1)
        #expect(setup.gate.began.count == 1)
        #expect(setup.model.currentSession?.sets.count == 2)
    }

    @Test func aWorkoutAfterDoneIsANewOne() async throws {
        let setup = try GateSetup(allows: true)
        try await setup.measureASet()
        await setup.model.finishSession()
        setup.gate.allows = false
        await setup.model.startPreview()
        #expect(setup.model.freeWorkoutUsed)
        #expect(setup.gate.questions == 2)
    }
}

@MainActor
private final class FakeGate: WorkoutStartGate {
    var allows: Bool
    private(set) var questions = 0
    private(set) var began: [Date] = []

    init(allows: Bool) { self.allows = allows }

    func allowsNewWorkout(at date: Date) async -> Bool {
        questions += 1
        return allows
    }

    func workoutBegan(at date: Date) { began.append(date) }
}

@MainActor
private final class GateSetup {
    let source = GateTestSource()
    let clock = GateTestClock()
    let gate: FakeGate
    let model: WorkoutSessionModel

    init(allows: Bool) throws {
        let defaults = try #require(UserDefaults(suiteName: "FinnFreeWorkout-\(UUID())"))
        let clock = clock
        gate = FakeGate(allows: allows)
        model = WorkoutSessionModel(
            source: source,
            preferences: FinnPreferences(defaults: defaults),
            currentDate: { clock.date }
        )
        model.startGate = gate
    }

    /// one measured six-rep squat set
    func measureASet() async throws {
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 6, from: 0) {
            source.emit(frame)
        }
        await model.endSet()
        guard case .measured = model.result else {
            Issue.record("Expected a measured set, got \(String(describing: model.result))")
            return
        }
    }
}

@MainActor
private final class GateTestClock {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(by interval: TimeInterval) { date = date.addingTimeInterval(interval) }
}

@MainActor
private final class GateTestSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    private var continuation: AsyncStream<PoseFrame>.Continuation?

    func start() async throws -> AsyncStream<PoseFrame> {
        AsyncStream { continuation in self.continuation = continuation }
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
    }

    func emit(_ frame: PoseFrame) { continuation?.yield(frame) }
}
