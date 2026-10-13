import Foundation

// Personalizing Plumb with what the person keeps in Apple Health. Everything here is plain logic on
// values already read, so it is tested without HealthKit; `HealthKitReader` does the reading. Plumb
// asks to read these types only once the person turns on Personalize with Health (in Options or in
// the one-time offer after a first set). Nothing read leaves the iPhone or serves another purpose.
// The notes speak like a coach about the person's own numbers, never like a diagnosis.

/// One kind of Health data Plumb may read, with the one sentence that says what it is used for.
nonisolated enum HealthReadType: String, CaseIterable, Equatable, Sendable {
    case heartRate
    case restingHeartRate
    case heartRateVariability
    case vo2Max
    case workouts
    case activeEnergy
    case steps
    case sleep
    case age
    case weight
    case height

    var title: String {
        switch self {
        case .heartRate: "Heart rate"
        case .restingHeartRate: "Resting heart rate"
        case .heartRateVariability: "Heart rate variability"
        case .vo2Max: "Cardio fitness (VO2 max)"
        case .workouts: "Workouts"
        case .activeEnergy: "Active energy"
        case .steps: "Steps"
        case .sleep: "Sleep"
        case .age: "Age"
        case .weight: "Weight"
        case .height: "Height"
        }
    }

    /// What Plumb does with it, in one sentence.
    var use: String {
        switch self {
        case .heartRate: "Shows your heart rate during a set and how fast it comes down while you rest."
        case .restingHeartRate: "Compared with your own weekly average to see whether you seem less recovered."
        case .heartRateVariability: "Compared with your own weekly average, as a second sign of recovery."
        case .vo2Max: "Shown next to your recovery so you can follow your cardio fitness."
        case .workouts: "Spots a long workout yesterday, to suggest an easier day."
        case .activeEnergy: "Spots a much busier day than usual yesterday."
        case .steps: "Spots a day with far more walking than usual yesterday."
        case .sleep: "Spots a short night, to suggest a lighter session."
        case .age: "Estimates your maximum heart rate, to say how hard a set was."
        case .weight: "Estimates the load of each rep, such as the weight a push-up lifts."
        case .height: "Turns squat depth into centimeters."
        }
    }
}

/// A workout found in Health, from any app.
nonisolated struct RecentWorkout: Equatable, Sendable {
    let start: Date
    let end: Date
    var minutes: Double { end.timeIntervalSince(start) / 60 }
}

/// What Plumb read from Health. Every value is optional: a person may have no watch, may have
/// refused a type, or may not have entered their age or weight.
nonisolated struct HealthSnapshot: Equatable, Sendable {
    /// Latest resting heart rate from the last 24 hours, in beats per minute.
    var restingHeartRate: Double?
    /// Mean resting heart rate over the 7 days before that.
    var restingHeartRateBaseline: Double?
    /// Latest heart rate variability (SDNN) from the last 24 hours, in milliseconds.
    var heartRateVariability: Double?
    var heartRateVariabilityBaseline: Double?
    /// Latest VO2 max, in mL/(kg·min).
    var vo2Max: Double?
    /// Workouts that ended yesterday (local calendar day).
    var workoutsYesterday: [RecentWorkout] = []
    /// Active energy burned yesterday, in kilocalories, and the daily mean of the 7 days before.
    var activeEnergyYesterday: Double?
    var activeEnergyBaseline: Double?
    var stepsYesterday: Double?
    var stepsBaseline: Double?
    /// Time asleep in the night that ended this morning, in seconds.
    var sleepLastNight: TimeInterval?
    var age: Int?
    /// Kilograms.
    var weight: Double?
    /// Meters.
    var height: Double?

    var isEmpty: Bool { self == HealthSnapshot() }
}

/// One personalized line, with the Health data it rests on, so the person sees why Plumb says it.
nonisolated struct HealthNote: Equatable, Sendable {
    let text: String
    /// Such as "From your resting heart rate in Health."
    let basis: String
}

/// Heart rate during one set, from the Apple Watch.
nonisolated struct SetHeartRate: Equatable, Sendable {
    let average: Int
    let peak: Int

    /// Nil without at least two readings.
    static func make(_ readings: [Double]) -> SetHeartRate? {
        let valid = readings.filter { $0.isFinite && $0 > 25 && $0 < 250 }
        guard valid.count >= 2 else { return nil }
        let average = valid.reduce(0, +) / Double(valid.count)
        return SetHeartRate(average: Int(average.rounded()), peak: Int((valid.max() ?? average).rounded()))
    }
}

nonisolated enum HealthCoach {
    /// Below this, a night counts as short.
    static let shortNight: TimeInterval = 6 * 3600
    /// Workouts that add up to this many minutes yesterday make a heavy day.
    static let heavyWorkoutMinutes = 60.0
    /// A day this many times the person's usual active energy or steps is a heavy day.
    static let busyDayFactor = 1.4
    /// Resting heart rate this many beats above the weekly average reads as less recovered.
    static let restingHeartRateRise = 5.0
    /// Heart rate variability this share of the weekly average or less reads as less recovered.
    static let variabilityDrop = 0.8
    /// Rest between sets before any personal adjustment, in seconds.
    static let baseRest = 90
    static let longerRest = 30
    static let maximumRest = 180

    /// Whether the person seems less recovered than usual, with the numbers behind it.
    static func recoveryNote(_ health: HealthSnapshot) -> HealthNote? {
        if let today = health.restingHeartRate, let usual = health.restingHeartRateBaseline,
           today - usual >= restingHeartRateRise {
            return HealthNote(
                text: "You seem less recovered than usual: your resting heart rate is \(bpm(today)), against \(bpm(usual)) on average this week.",
                basis: "From your resting heart rate in Health.")
        }
        if let today = health.heartRateVariability, let usual = health.heartRateVariabilityBaseline,
           usual > 0, today <= usual * variabilityDrop {
            return HealthNote(
                text: "You seem less recovered than usual: your heart rate variability is \(Int(today.rounded())) ms, against \(Int(usual.rounded())) ms on average this week.",
                basis: "From your heart rate variability in Health.")
        }
        return nil
    }

    /// Before the first set of the day: a lighter session after a short night or a heavy day.
    static func readiness(_ health: HealthSnapshot) -> HealthNote? {
        if let recovery = recoveryNote(health) {
            return HealthNote(text: recovery.text + " A lighter session today?", basis: recovery.basis)
        }
        if let sleep = health.sleepLastNight, sleep > 0, sleep < shortNight {
            return HealthNote(text: "Lighter session today? You slept \(duration(sleep)) last night.",
                              basis: "From your sleep in Health.")
        }
        let minutes = health.workoutsYesterday.reduce(0) { $0 + $1.minutes }
        if minutes >= heavyWorkoutMinutes {
            return HealthNote(text: "Yesterday looked heavy, with \(Int(minutes.rounded())) minutes of workouts. A lighter session today could help you recover.",
                              basis: "From your workouts in Health.")
        }
        if let energy = health.activeEnergyYesterday, let usual = health.activeEnergyBaseline, usual > 0,
           energy >= usual * busyDayFactor {
            return HealthNote(text: "Yesterday was much busier than usual: \(Int(energy.rounded())) kcal of active energy, against \(Int(usual.rounded())) on a usual day. Go easier if you feel it.",
                              basis: "From your active energy in Health.")
        }
        if let steps = health.stepsYesterday, let usual = health.stepsBaseline, usual >= 3000,
           steps >= usual * busyDayFactor {
            return HealthNote(text: "You walked far more than usual yesterday: \(Int(steps.rounded())) steps, against \(Int(usual.rounded())) on a usual day. Go easier if your legs feel it.",
                              basis: "From your steps in Health.")
        }
        return nil
    }

    /// The rest to take before the next set. With the watch's heart rate, Plumb also gives the heart
    /// rate to wait for: back under the resting rate plus 40% of the way to the set's peak.
    static func rest(health: HealthSnapshot?, setHeartRate: SetHeartRate?, currentHeartRate: Int?) -> HealthNote? {
        var seconds = baseRest
        var reasons: [String] = []
        var bases: [String] = []
        if let health {
            if let recovery = recoveryNote(health) {
                seconds += longerRest
                reasons.append("you seem less recovered than usual")
                bases.append(recovery.basis.contains("variability") ? "heart rate variability" : "resting heart rate")
            }
            if let sleep = health.sleepLastNight, sleep > 0, sleep < shortNight {
                seconds += longerRest
                reasons.append("your night was short")
                bases.append("sleep")
            }
        }
        seconds = min(seconds, maximumRest)
        var text = "Rest about \(restText(seconds)) before your next set"
        text += reasons.isEmpty ? "." : ", since " + reasons.joined(separator: " and ") + "."
        if let setHeartRate, let resting = health?.restingHeartRate ?? health?.restingHeartRateBaseline,
           Double(setHeartRate.peak) > resting + 10 {
            let target = Int((resting + 0.4 * (Double(setHeartRate.peak) - resting)).rounded())
            text += " Or wait until your heart rate is back under \(target) bpm"
            text += currentHeartRate.map { " (now \($0))." } ?? "."
            bases.insert("heart rate from your Apple Watch", at: 0)
            if !bases.contains("resting heart rate") { bases.append("resting heart rate") }
        }
        guard !bases.isEmpty else { return nil }
        return HealthNote(text: text, basis: "From your " + list(bases) + " in Health.")
    }

    /// How hard the set was for the heart, with the age-based maximum when the age is known.
    static func heartRateLine(_ heartRate: SetHeartRate, age: Int?) -> HealthNote {
        var text = "Heart rate during the set: \(heartRate.average) bpm on average, peak \(heartRate.peak)"
        var basis = "From your Apple Watch."
        if let age, age >= 13, age <= 100 {
            // Tanaka's estimate, 208 − 0.7 × age: a rough population figure, not a measured maximum.
            let maximum = 208 - 0.7 * Double(age)
            let share = Int((Double(heartRate.peak) / maximum * 100).rounded())
            text += ", about \(share)% of the usual maximum at your age"
            basis = "From your Apple Watch and your age in Health."
        }
        return HealthNote(text: text + ".", basis: basis)
    }

    /// Share of body weight a rep moves, from published biomechanics estimates.
    static func bodyWeightShare(for exercise: ExerciseKind) -> Double? {
        switch exercise {
        case .pushUp: 0.64
        case .bodyweightSquat, .staticLunge: 0.85
        case .stiffLegDeadlift: nil
        // The whole body hangs from the bar.
        case .pullUp, .muscleUp: 1.0
        }
    }

    /// For example "Each push-up lifted about 45 kg, 64% of your weight."
    static func loadLine(for exercise: ExerciseKind, weight: Double?) -> HealthNote? {
        guard let weight, weight >= 25, weight <= 300, let share = bodyWeightShare(for: exercise) else { return nil }
        let noun = exercise.definition.copy.name.lowercased()
        return HealthNote(
            text: "Each \(noun) moved about \(Int((weight * share).rounded())) kg, roughly \(Int((share * 100).rounded()))% of your weight.",
            basis: "From your weight in Health.")
    }

    /// The deepest squat in centimeters: the hip drop is measured as a share of the standing hip
    /// height, taken here as 48% of body height.
    static func depthLine(for exercise: ExerciseKind, deepestRange: Double?, height: Double?) -> HealthNote? {
        guard exercise == .bodyweightSquat, let deepestRange, deepestRange > 0,
              let height, height >= 1.2, height <= 2.3 else { return nil }
        let centimeters = Int((deepestRange * 0.48 * height * 100).rounded())
        return HealthNote(text: "Your hips went down about \(centimeters) cm on your deepest squat.",
                          basis: "From your height in Health.")
    }

    /// The person's cardio fitness, shown as a number to follow, not a judgment.
    static func fitnessLine(_ health: HealthSnapshot) -> HealthNote? {
        guard let vo2 = health.vo2Max, vo2 > 10, vo2 < 90 else { return nil }
        return HealthNote(text: String(format: "Cardio fitness: VO2 max %.1f.", vo2),
                          basis: "From your cardio fitness in Health.")
    }

    /// Total time asleep in `intervals`, counting overlapping records from several sources once.
    static func asleep(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in sorted {
            if let open = current, interval.start <= open.end {
                current = DateInterval(start: open.start, end: max(open.end, interval.end))
            } else {
                if let open = current { total += open.duration }
                current = interval
            }
        }
        if let open = current { total += open.duration }
        return total
    }

    static func bpm(_ value: Double) -> String { "\(Int(value.rounded())) bpm" }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }

    static func restText(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(seconds % 60) s"
    }

    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        default: items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }
}

/// Reads Health for personalization. `HealthKitReader` in the app; fakes in tests.
protocol HealthReading: AnyObject {
    /// False where Health is not available, such as some iPads.
    var isAvailable: Bool { get }
    /// Shows Health's sheet for the types the person has not answered yet. HealthKit never says
    /// which read types were refused: a refused type simply reads as no data.
    func requestAccess() async
    func snapshot(now: Date) async -> HealthSnapshot
}
