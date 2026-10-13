import Foundation
import HealthKit

/// Saves finished Plumb sessions to Apple Health as workouts, so they appear in the Fitness app's
/// workout history and in Health. Plumb asks only to share (write) workouts and reads nothing.
/// Everything worth testing is in `FitnessWorkout` and `WorkoutSessionModel`; this file only maps
/// it to HealthKit.
///
/// APIs as documented by Apple (checked October 2026):
/// - `HKHealthStore.isHealthDataAvailable()`, before any other HealthKit call.
/// - `authorizationStatus(for:)` reports the share (write) permission, the only one an app can read.
/// - `requestAuthorization(toShare:read:) async throws` (iOS 15+) shows the sheet only for types the
///   person has not answered.
/// - `HKWorkoutBuilder(healthStore:configuration:device:)`, `beginCollection(at:)`,
///   `addWorkoutEvents(_:)`, `addMetadata(_:)`, `endCollection(at:)`, `finishWorkout()`: Apple's
///   replacement for the `HKWorkout` initializers deprecated in iOS 17. `finishWorkout()` returns nil
///   when the workout was saved while the device is locked.
final class HealthKitWorkoutExporter: FitnessWorkoutSaving {
    /// One long-lived store per app, as Apple advises. Created on first use: until the person turns
    /// the option on, Plumb does not touch HealthKit.
    private lazy var store = HKHealthStore()

    var authorization: FitnessAuthorization {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestAuthorization() async -> FitnessAuthorization {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        do {
            // Share workouts only; nothing to read.
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
        } catch {
            // Fails without the entitlement or usage description, or when Health is restricted.
            // The status read below then reports what Plumb may do.
        }
        return authorization
    }

    func save(_ workout: FitnessWorkout) async throws -> UUID? {
        guard HKHealthStore.isHealthDataAvailable() else { throw FitnessSaveError.unavailable }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workout.activity.healthKitType
        configuration.locationType = workout.isIndoor ? .indoor : .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration,
                                       device: HKDevice.local())
        do {
            try await builder.beginCollection(at: workout.start)
            if !workout.pauses.isEmpty {
                try await builder.addWorkoutEvents(Self.events(for: workout.pauses))
            }
            try await builder.addMetadata(Self.metadata(for: workout))
            try await builder.endCollection(at: workout.end)
            let saved = try await builder.finishWorkout()
            return saved?.uuid
        } catch {
            builder.discardWorkout()
            throw Self.fitnessError(for: error)
        }
    }

    /// A pause and a resume event (zero-length intervals) per long break; HealthKit leaves the time
    /// between them out of the workout's duration.
    private static func events(for pauses: [DateInterval]) -> [HKWorkoutEvent] {
        pauses.flatMap { pause in
            [HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil),
             HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil)]
        }
    }

    /// HealthKit metadata takes string keys with `NSString`, `NSNumber` or `NSDate` values. No energy
    /// or heart rate: Plumb measures neither.
    private static func metadata(for workout: FitnessWorkout) -> [String: Any] {
        var metadata: [String: Any] = [
            HKMetadataKeyIndoorWorkout: NSNumber(value: workout.isIndoor),
            // One workout per session: HealthKit replaces an object with the same sync identifier only
            // when the new sync version is greater.
            HKMetadataKeySyncIdentifier: NSString(string: workout.syncIdentifier),
            HKMetadataKeySyncVersion: NSNumber(value: FitnessWorkout.syncVersion),
        ]
        for (key, value) in workout.plumbMetadata {
            switch value {
            case .text(let text): metadata[key] = NSString(string: text)
            case .number(let number): metadata[key] = NSNumber(value: number)
            }
        }
        return metadata
    }

    private static func fitnessError(for error: Error) -> Error {
        guard let healthError = error as? HKError else { return error }
        switch healthError.code {
        case .errorAuthorizationDenied, .errorAuthorizationNotDetermined: return FitnessSaveError.notAuthorized
        case .errorHealthDataUnavailable, .errorHealthDataRestricted: return FitnessSaveError.unavailable
        default: return error
        }
    }
}

private extension FitnessActivity {
    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .functionalStrengthTraining: .functionalStrengthTraining
        }
    }
}
