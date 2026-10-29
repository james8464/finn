import AVFoundation
import Foundation
import Testing
@testable import Finn

/// Personalize with Health: the coach's rules on values already read, and the session model's offer,
/// permission and heart rate, with a fake in place of HealthKit.
struct HealthCoachTests {
    @Test func aShortNightSuggestsALighterSessionAndSaysItComesFromSleep() throws {
        var health = HealthSnapshot()
        health.sleepLastNight = 5 * 3600 + 40 * 60
        let note = try #require(HealthCoach.readiness(health))
        #expect(note.text == "Lighter session today? You slept 5 h 40 last night.")
        #expect(note.basis == "From your sleep in Health.")
    }

    @Test func aRaisedRestingHeartRateReadsAsLessRecoveredThanUsual() throws {
        var health = HealthSnapshot()
        health.restingHeartRate = 64
        health.restingHeartRateBaseline = 57
        health.sleepLastNight = 8 * 3600
        let note = try #require(HealthCoach.readiness(health))
        #expect(note.text.contains("less recovered than usual"))
        #expect(note.text.contains("64 bpm, against 57 bpm"))
        #expect(note.basis == "From your resting heart rate in Health.")
    }

    @Test func aHeavyDayYesterdayIsPointedOutWithItsMinutes() throws {
        var health = HealthSnapshot()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        health.workoutsYesterday = [RecentWorkout(start: start, end: start.addingTimeInterval(45 * 60)),
                                    RecentWorkout(
                                        start: start.addingTimeInterval(3600),
                                        end: start.addingTimeInterval(3600 + 30 * 60)
                                    )]
        let note = try #require(HealthCoach.readiness(health))
        #expect(note.text.contains("75 minutes of workouts"))
        #expect(note.basis == "From your workouts in Health.")
    }

    @Test func usualNumbersSayNothing() {
        var health = HealthSnapshot()
        health.restingHeartRate = 58
        health.restingHeartRateBaseline = 57
        health.heartRateVariability = 52
        health.heartRateVariabilityBaseline = 55
        health.sleepLastNight = 7.5 * 3600
        health.activeEnergyYesterday = 500
        health.activeEnergyBaseline = 480
        health.stepsYesterday = 9000
        health.stepsBaseline = 8500
        #expect(HealthCoach.readiness(health) == nil)
        #expect(HealthCoach.rest(health: health, setHeartRate: nil, currentHeartRate: nil) == nil)
    }

    @Test func restGrowsWhenLessRecoveredAndFollowsTheWatchHeartRate() throws {
        var health = HealthSnapshot()
        health.restingHeartRate = 66
        health.restingHeartRateBaseline = 58
        let longer = try #require(HealthCoach.rest(health: health, setHeartRate: nil, currentHeartRate: nil))
        #expect(longer
            .text == "Rest about 2 min before your next set, since you seem less recovered than usual.")
        #expect(longer.basis == "From your resting heart rate in Health.")

        health.restingHeartRate = 60
        health.restingHeartRateBaseline = 60
        let withWatch = try #require(HealthCoach.rest(
            health: health,
            setHeartRate: SetHeartRate(average: 130, peak: 150),
            currentHeartRate: 121
        ))
        // 60 + 0.4 × (150 − 60) = 96.
        #expect(withWatch
            .text ==
            "Rest about 1 min 30 s before your next set. Or wait until your heart rate is back under 96 bpm (now 121).")
        #expect(withWatch
            .basis == "From your heart rate from your Apple Watch and resting heart rate in Health.")
    }

    @Test func heartRateLoadAndDepthLinesUseAgeWeightAndHeight() throws {
        let heart = HealthCoach.heartRateLine(SetHeartRate(average: 128, peak: 150), age: 30)
        // 208 − 0.7 × 30 = 187; 150 / 187 = 80%.
        #expect(heart
            .text ==
            "Heart rate during the set: 128 bpm on average, peak 150, about 80% of the usual maximum at your age.")
        #expect(HealthCoach.heartRateLine(SetHeartRate(average: 128, peak: 150), age: nil)
            .basis == "From your Apple Watch.")

        let load = try #require(HealthCoach.loadLine(for: .pushUp, weight: 70))
        #expect(load.text == "Each push-up moved about 45 kg, roughly 64% of your weight.")
        #expect(HealthCoach.loadLine(for: .stiffLegDeadlift, weight: 70) == nil)

        let depth = try #require(HealthCoach.depthLine(
            for: .bodyweightSquat,
            deepestRange: 0.30,
            height: 1.80
        ))
        #expect(depth.text == "Your hips went down about 26 cm on your deepest squat.")
        #expect(HealthCoach.depthLine(for: .pushUp, deepestRange: 40, height: 1.80) == nil)
    }

    @Test func overlappingSleepFromTwoSourcesCountsOnce() {
        let night = Date(timeIntervalSince1970: 1_800_000_000)
        let asleep = HealthCoach.asleep([
            DateInterval(start: night, duration: 3 * 3600),
            DateInterval(start: night.addingTimeInterval(2 * 3600), duration: 3 * 3600),
            DateInterval(start: night.addingTimeInterval(6 * 3600), duration: 3600),
        ])
        #expect(asleep == 6 * 3600)
    }

    @Test func setHeartRateNeedsTwoPlausibleReadings() {
        #expect(SetHeartRate.make([120]) == nil)
        #expect(SetHeartRate.make([110, 130, 400, .nan]) == SetHeartRate(average: 120, peak: 130))
    }

    @Test func todayIsComparedWithTheWeekBefore() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let samples = [(date: now.addingTimeInterval(-3 * 86_400), value: 56.0),
                       (date: now.addingTimeInterval(-2 * 86_400), value: 58.0),
                       (date: now.addingTimeInterval(-3600), value: 65.0)]
        let (latest, baseline) = HealthKitReader.latestAndBaseline(samples, now: now)
        #expect(latest == 65)
        #expect(baseline == 57)

        let calendar = Calendar.current
        let yesterday = calendar.startOfDay(for: now).addingTimeInterval(-86_400)
        let days = [(day: yesterday.addingTimeInterval(-2 * 86_400), sum: 400.0),
                    (day: yesterday.addingTimeInterval(-86_400), sum: 600.0),
                    (day: yesterday, sum: 900.0)]
        let (value, usual) = HealthKitReader.yesterdayAndBaseline(days, yesterday: yesterday)
        #expect(value == 900)
        #expect(usual == 500)
    }

    @Test func heartRateTravelsFromTheWatchAndTheWatchIsToldToMeasureIt() throws {
        let reading = WatchHeartRate(beatsPerMinute: 132, measuredAt: 1_800_000_000)
        let data = try PropertyListSerialization.data(
            fromPropertyList: reading.message(),
            format: .binary,
            options: 0
        )
        let decoded = try #require(try PropertyListSerialization
            .propertyList(from: data, format: nil) as? [String: Any])
        #expect(WatchHeartRate(message: decoded) == reading)
        #expect(WatchCommand(message: decoded) == nil)

        let state = WatchState(stage: .capturing, measuresHeartRate: true)
        #expect(WatchState(message: state.message())?.measuresHeartRate == true)
        let demo = WatchSyncRules.state(
            stage: .capturing,
            exercise: .bodyweightSquat,
            liveReps: 0,
            caption: nil,
            result: nil,
            cueDismissed: false,
            handsFree: false,
            demoInput: true,
            measuresHeartRate: true
        )
        #expect(!demo.measuresHeartRate)
    }
}

@MainActor
struct HealthSessionTests {
    @Test func theOfferShowsOnceAfterTheFirstMeasuredSetAndLaterKeepsHealthUntouched() async throws {
        let setup = try HealthSetup()
        #expect(!setup.model.showsPersonalisationOffer)
        await setup.measureASet()
        #expect(setup.model.showsPersonalisationOffer)
        await setup.model.answerPersonalisationOffer(personalise: false)
        #expect(!setup.model.showsPersonalisationOffer)
        #expect(!setup.model.personalisesWithHealth)
        #expect(setup.health.requests == 0)
        #expect(setup.health.reads == 0)

        await setup.measureASet()
        #expect(!setup.model.showsPersonalisationOffer)
        #expect(setup.model.resultHealthNotes.isEmpty)
    }

    @Test func yesAsksHealthReadsItAndPersonalizesTheResult() async throws {
        let setup = try HealthSetup()
        setup.health.snapshotToReturn.restingHeartRate = 60
        setup.health.snapshotToReturn.restingHeartRateBaseline = 60
        setup.health.snapshotToReturn.weight = 70
        setup.health.snapshotToReturn.sleepLastNight = 5 * 3600
        await setup.measureASet()
        await setup.model.answerPersonalisationOffer(personalise: true)
        #expect(setup.model.personalisesWithHealth)
        #expect(setup.health.requests == 1)
        #expect(setup.model.readinessNote?.basis == "From your sleep in Health.")

        // the watch sends its heart rate while the next set runs.
        await setup.model.startPreview()
        await setup.model.beginSet(countdown: 0)
        setup.model.receiveHeartRate(118, at: setup.clock.date)
        setup.clock.advance(by: 5)
        setup.model.receiveHeartRate(142, at: setup.clock.date)
        for frame in CaptureTraces.squats(reps: 6, from: 0) {
            setup.source.emit(frame)
        }
        await setup.model.endSet()
        #expect(setup.model.setHeartRate == SetHeartRate(average: 130, peak: 142))
        let texts = setup.model.resultHealthNotes.map(\.text)
        #expect(texts.contains { $0.hasPrefix("Heart rate during the set: 130 bpm on average, peak 142") })
        #expect(texts
            .contains { $0.hasPrefix("Rest about 2 min before your next set, since your night was short.") })
        #expect(texts.contains("Each squat moved about 60 kg, roughly 85% of your weight."))

        // turned off in Options: nothing personal is shown and no heart rate is kept.
        await setup.model.setPersonalisesWithHealth(false)
        #expect(setup.model.resultHealthNotes.isEmpty)
        #expect(setup.model.readinessNote == nil)
    }

    @Test func demoInputNeverOffersOrReadsHealth() async throws {
        let setup = try HealthSetup(withHealth: false)
        await setup.measureASet()
        #expect(!setup.model.offersHealthPersonalisation)
        #expect(!setup.model.showsPersonalisationOffer)
    }

    /// A failed HealthKit read is not an empty one: the last good snapshot stays, so a transient
    /// error cannot read as "you slept nothing".
    @Test func aFailedHealthReadKeepsTheLastGoodSnapshot() async throws {
        let setup = try HealthSetup()
        setup.health.snapshotToReturn.sleepLastNight = 5 * 3600
        await setup.model.answerPersonalisationOffer(personalise: true)
        #expect(setup.model.readinessNote?.basis == "From your sleep in Health.")

        setup.health.failsRead = true
        await setup.model.refreshHealth()
        #expect(setup.health.reads == 2)
        #expect(setup.model.readinessNote?.basis == "From your sleep in Health.")
    }

    /// A short night reads in minutes, never as "0 h 45".
    @Test func sleepLengthUnderAnHourReadsInMinutes() {
        #expect(HealthCoach.duration(TimeInterval(45 * 60)) == "45 min")
        #expect(HealthCoach.duration(TimeInterval(5 * 3600 + 40 * 60)) == "5 h 40")
        #expect(HealthCoach.duration(7.5 * 3600) == "7 h 30")
    }
}

@MainActor
private final class HealthSetup {
    let source = HealthTestSource()
    let health = FakeHealthReader()
    let clock = HealthTestClock()
    let model: WorkoutSessionModel

    init(withHealth: Bool = true) throws {
        let defaults = try #require(UserDefaults(suiteName: "FinnHealth-\(UUID())"))
        let clock = clock
        model = WorkoutSessionModel(
            source: source,
            preferences: FinnPreferences(defaults: defaults),
            health: withHealth ? health : nil,
            currentDate: { clock.date }
        )
        model.recognisesExercise = false
    }

    func measureASet() async {
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for frame in CaptureTraces.squats(reps: 6, from: 0) {
            source.emit(frame)
        }
        await model.endSet()
        guard case .measured = model.result else {
            Issue.record("Expected a measured squat set, got \(String(describing: model.result))")
            return
        }
    }
}

@MainActor
private final class HealthTestClock {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(by interval: TimeInterval) {
        date = date.addingTimeInterval(interval)
    }
}

@MainActor
private final class FakeHealthReader: HealthReading {
    var isAvailable = true
    var snapshotToReturn = HealthSnapshot()
    /// stands for a HealthKit query that threw, rather than returned no samples
    var failsRead = false
    private(set) var requests = 0
    private(set) var reads = 0

    func requestAccess() async {
        requests += 1
    }

    func snapshot(now: Date) async -> HealthSnapshot? {
        reads += 1
        return failsRead ? nil : snapshotToReturn
    }
}

private final class HealthTestSource: PoseStreaming {
    let previewSession = AVCaptureSession()
    private var continuation: AsyncStream<PoseFrame>.Continuation?

    func start() async throws -> AsyncStream<PoseFrame> {
        AsyncStream { continuation in self.continuation = continuation }
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
    }

    func emit(_ frame: PoseFrame) {
        continuation?.yield(frame)
    }
}
