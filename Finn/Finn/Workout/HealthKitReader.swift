import Foundation
import HealthKit

/// Reads what Personalize with Health needs from Apple Health. Only `HealthCoach` decides what to
/// say; this file maps HealthKit samples to a `HealthSnapshot`. It touches HealthKit only after the
/// person turned the option on, and keeps nothing: each snapshot is read again when needed.
///
/// APIs as documented by Apple (checked October 2026): `requestAuthorization(toShare:read:)`,
/// `HKSampleQueryDescriptor` and `HKStatisticsCollectionQueryDescriptor` with `result(for:)`,
/// `dateOfBirthComponents()`. Read permission is private: a refused type returns no samples.
final class HealthKitReader: HealthReading {
    private lazy var store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType(), HKCategoryType(.sleepAnalysis)]
        for identifier: HKQuantityTypeIdentifier in [.heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
                                                     .vo2Max, .activeEnergyBurned, .stepCount, .bodyMass, .height] {
            types.insert(HKQuantityType(identifier))
        }
        types.insert(HKCharacteristicType(.dateOfBirth))
        return types
    }

    func requestAccess() async {
        guard isAvailable else { return }
        // Finn keeps sharing only workouts (Save workouts to Apple Fitness asks for that one).
        try? await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func snapshot(now: Date) async -> HealthSnapshot {
        guard isAvailable else { return HealthSnapshot() }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekBefore = calendar.date(byAdding: .day, value: -8, to: today) ?? today
        var health = HealthSnapshot()

        let resting = await samples(.restingHeartRate, unit: .count().unitDivided(by: .minute()),
                                    from: weekBefore, to: now)
        (health.restingHeartRate, health.restingHeartRateBaseline) = Self.latestAndBaseline(resting, now: now)
        let variability = await samples(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli),
                                        from: weekBefore, to: now)
        (health.heartRateVariability, health.heartRateVariabilityBaseline) = Self.latestAndBaseline(variability, now: now)
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: today) ?? today
        health.vo2Max = await samples(.vo2Max, unit: HKUnit(from: "ml/kg*min"), from: ninetyDaysAgo, to: now).last?.value

        health.workoutsYesterday = await workouts(endingFrom: yesterday, to: today)
        let energy = await dailySums(.activeEnergyBurned, unit: .kilocalorie(), from: weekBefore, to: today)
        (health.activeEnergyYesterday, health.activeEnergyBaseline) = Self.yesterdayAndBaseline(energy, yesterday: yesterday)
        let steps = await dailySums(.stepCount, unit: .count(), from: weekBefore, to: today)
        (health.stepsYesterday, health.stepsBaseline) = Self.yesterdayAndBaseline(steps, yesterday: yesterday)

// the night that ended this morning: from 6 p.m. yesterday to noon today, or now if earlier.
        let nightStart = calendar.date(byAdding: .hour, value: 18, to: yesterday) ?? yesterday
        let nightEnd = min(now, calendar.date(byAdding: .hour, value: 12, to: today) ?? now)
        let asleep = await sleepIntervals(from: nightStart, to: nightEnd)
        health.sleepLastNight = asleep.isEmpty ? nil : HealthCoach.asleep(asleep)

        if let birth = try? store.dateOfBirthComponents(), let birthDate = calendar.date(from: birth) {
            health.age = calendar.dateComponents([.year], from: birthDate, to: now).year
        }
        let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: today) ?? today
        health.weight = await samples(.bodyMass, unit: .gramUnit(with: .kilo), from: tenYearsAgo, to: now).last?.value
        health.height = await samples(.height, unit: .meter(), from: tenYearsAgo, to: now).last?.value
        return health
    }

    /// The latest value of the last 24 hours, and the mean of the values before it.
    static func latestAndBaseline(_ samples: [(date: Date, value: Double)], now: Date) -> (Double?, Double?) {
        let cutoff = now.addingTimeInterval(-24 * 3600)
        let latest = samples.last(where: { $0.date >= cutoff })?.value
        let earlier = samples.filter { $0.date < cutoff }.map(\.value)
        let baseline = earlier.isEmpty ? nil : earlier.reduce(0, +) / Double(earlier.count)
        return (latest, baseline)
    }

    /// Yesterday's total, and the mean of the days before it that have data.
    static func yesterdayAndBaseline(_ days: [(day: Date, sum: Double)], yesterday: Date) -> (Double?, Double?) {
        let value = days.first(where: { $0.day == yesterday })?.sum
        let earlier = days.filter { $0.day < yesterday && $0.sum > 0 }.map(\.sum)
        let baseline = earlier.isEmpty ? nil : earlier.reduce(0, +) / Double(earlier.count)
        return (value, baseline)
    }

    private func samples(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
                         from start: Date, to end: Date) async -> [(date: Date, value: Double)] {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)],
                                                 sortDescriptors: [SortDescriptor(\.endDate, order: .forward)])
        guard let results = try? await descriptor.result(for: store) else { return [] }
        return results.map { ($0.endDate, $0.quantity.doubleValue(for: unit)) }
    }

    private func dailySums(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
                           from start: Date, to end: Date) async -> [(day: Date, sum: Double)] {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate), options: .cumulativeSum,
            anchorDate: start, intervalComponents: DateComponents(day: 1))
        guard let collection = try? await descriptor.result(for: store) else { return [] }
        var days: [(day: Date, sum: Double)] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            days.append((statistics.startDate, statistics.sumQuantity()?.doubleValue(for: unit) ?? 0))
        }
        return days
    }

    private func workouts(endingFrom start: Date, to end: Date) async -> [RecentWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)],
                                                 sortDescriptors: [SortDescriptor(\.endDate, order: .forward)])
        guard let results = try? await descriptor.result(for: store) else { return [] }
        return results.map { RecentWorkout(start: $0.startDate, end: $0.endDate) }
    }

    private func sleepIntervals(from start: Date, to end: Date) async -> [DateInterval] {
        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                                HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)])
        guard let results = try? await descriptor.result(for: store) else { return [] }
        return results.compactMap { sample in
            let from = max(sample.startDate, start), to = min(sample.endDate, end)
            // DateInterval traps when its end is before its start.
            guard asleep.contains(sample.value), to > from else { return nil }
            return DateInterval(start: from, end: to)
        }
    }
}
