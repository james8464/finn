import Foundation
import HealthKit
import Observation

/// a temporary HealthKit workout keeps local rhythm haptics available with the wrist lowered
/// no heart-rate samples are requested, and the workout is discarded when capture ends
@Observable
@MainActor
final class RhythmWorkoutSession {
    private(set) var isRunning = false
    private(set) var permissionDenied = false
    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var generation = 0

    func requestPermission() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            permissionDenied = true
            return false
        }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            let allowed = store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
            permissionDenied = !allowed
            return allowed
        } catch {
            permissionDenied = true
            return false
        }
    }

    func start() async -> Bool {
        if isRunning {
            return true
        }
        guard !isStarting, store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
        else {
            return false
        }
        isStarting = true
        let currentGeneration = generation
        defer { isStarting = false }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            self.session = session
            self.builder = builder
            let startedAt = Date()
            session.startActivity(with: startedAt)
            try await builder.beginCollection(at: startedAt)
            guard generation == currentGeneration else {
                session.end()
                try? await builder.endCollection(at: Date())
                builder.discardWorkout()
                return false
            }
            isRunning = true
            return true
        } catch {
            session?.end()
            session = nil
            builder = nil
            return false
        }
    }

    func stop() {
        generation += 1
        guard let session, let builder else {
            return
        }
        self.session = nil
        self.builder = nil
        isRunning = false
        session.end()
        Task {
            try? await builder.endCollection(at: Date())
            builder.discardWorkout()
        }
    }
}
