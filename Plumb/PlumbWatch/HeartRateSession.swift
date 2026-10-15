import Foundation
import HealthKit
import Observation

/// A workout session on the watch while the iPhone camera is open, only when the person turned on
/// Personalize with Health. It reads the heart rate, shows it on the wrist and hands each reading to
/// `onHeartRate`, which sends it to the iPhone. The session keeps the watch app running with the
/// wrist down. Its workout is discarded at the end: the iPhone saves the session to Fitness itself
/// (Save workouts to Apple Fitness), so Fitness never shows the same workout twice.
@Observable
@MainActor
final class HeartRateSession: NSObject {
    private(set) var beatsPerMinute: Int?
    private(set) var isRunning = false
    /// Why there is no heart rate, when Health refused or is unavailable.
    private(set) var problem: String?
    @ObservationIgnored var onHeartRate: ((Double, Date) -> Void)?
    @ObservationIgnored private lazy var store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var isStarting = false

    func start() async {
        guard !isRunning, !isStarting, HKHealthStore.isHealthDataAvailable() else { return }
        isStarting = true
        defer { isStarting = false }
        let heartRate = HKQuantityType(.heartRate)
        try? await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [heartRate])
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            problem = String(localized: "Allow Plumb in Health on your iPhone to see your heart rate here.")
            return
        }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            builder.delegate = self
            self.session = session
            self.builder = builder
            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            isRunning = true
            problem = nil
        } catch {
            problem = String(localized: "Heart rate is not available right now.")
            session?.end()
            session = nil
            builder = nil
        }
    }

    func stop() {
        guard let session, let builder else { return }
        self.session = nil
        self.builder = nil
        isRunning = false
        beatsPerMinute = nil
        session.end()
        Task {
            try? await builder.endCollection(at: Date())
            builder.discardWorkout()
        }
    }

    private func received(_ beatsPerMinute: Double, at date: Date) {
        guard isRunning else { return }
        self.beatsPerMinute = Int(beatsPerMinute.rounded())
        onHeartRate?(beatsPerMinute, date)
    }
}

extension HeartRateSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heartRate = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRate),
              let quantity = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity() else { return }
        let value = quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        let date = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantityDateInterval()?.end ?? Date()
        Task { @MainActor [weak self] in self?.received(value, at: date) }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
