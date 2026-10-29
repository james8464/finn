import Foundation

/// Personalize with Health: what the session model reads from Health, what it says with it, and the
/// one-time offer after a first set. `HealthCoach` holds the rules.
extension WorkoutSessionModel {
    /// Health can be read on this device, for live camera sessions only.
    var offersHealthPersonalisation: Bool { health?.isAvailable ?? false }

    /// turns personalisation on or off from Options or the offer. Turning it on shows Health's sheet
    /// for the types not answered yet, then reads them.
    func setPersonalisesWithHealth(_ isOn: Bool) async {
        personalisesWithHealth = isOn
        preferences.personalisationOffered = true
        guard isOn else {
            healthSnapshot = nil
            return
        }
        await health?.requestAccess()
        await refreshHealth()
    }

    /// Reads Health again, when the option is on. Called when the setup screen shows. A read that
    /// fails keeps the last good snapshot, so a transient HealthKit error is not shown as no data.
    func refreshHealth() async {
        guard personalisesWithHealth, let health, health.isAvailable else { return }
        guard let snapshot = await health.snapshot(now: currentDate()) else { return }
// the person may have turned the option off while Health was read.
        guard personalisesWithHealth else { return }
        healthSnapshot = snapshot.validatedForCoaching
    }

    /// The answer to "Make Finn more personal?". Asked once, whatever the answer.
    func answerPersonalisationOffer(personalise: Bool) async {
        showsPersonalisationOffer = false
        preferences.personalisationOffered = true
        if personalise { await setPersonalisesWithHealth(true) }
    }

    /// after the first measured live set, offer personalisation once.
    func offerPersonalisationIfDue() {
        guard offersHealthPersonalisation, !personalisesWithHealth,
              !preferences.personalisationOffered else { return }
// counted as asked as soon as it shows: closing it with a swipe means "Later".
        preferences.personalisationOffered = true
        showsPersonalisationOffer = true
    }

    /// A heart rate from the Apple Watch. Kept for the set while it runs; shown during the rest after.
    func receiveHeartRate(_ beatsPerMinute: Double, at date: Date) {
        guard personalisesWithHealth, beatsPerMinute.isFinite, beatsPerMinute > 25, beatsPerMinute < 250 else { return }
        if let liveHeartRateAt, date < liveHeartRateAt { return }
        liveHeartRate = Int(beatsPerMinute.rounded())
        liveHeartRateAt = date
        if stage == .capturing { setHeartRateReadings.append(beatsPerMinute) }
    }

    /// The watch's heart rate, if it is recent enough to show.
    var currentHeartRate: Int? {
        guard let liveHeartRateAt, currentDate().timeIntervalSince(liveHeartRateAt) < 20 else { return nil }
        return liveHeartRate
    }

    /// Before a set: a lighter session after a short night, a heavy day or a sign of low recovery.
    var readinessNote: HealthNote? {
        guard personalisesWithHealth, let healthSnapshot else { return nil }
        return HealthCoach.readiness(healthSnapshot)
    }

    /// After a measured set: heart rate, rest, load and depth, each with the data it rests on.
    var resultHealthNotes: [HealthNote] {
        guard personalisesWithHealth, case .measured(let analysis, _) = result else { return [] }
        let snapshot = healthSnapshot
        var notes: [HealthNote] = []
        if let setHeartRate { notes.append(HealthCoach.heartRateLine(setHeartRate, age: snapshot?.age)) }
        if let rest = HealthCoach.rest(health: snapshot, setHeartRate: setHeartRate,
                                       currentHeartRate: currentHeartRate) {
            notes.append(rest)
        }
        if let load = HealthCoach.loadLine(for: resultExercise, weight: snapshot?.weight) { notes.append(load) }
        if let depth = HealthCoach.depthLine(for: resultExercise,
                                             deepestRange: analysis.reps.map(\.relativeRange).max(),
                                             height: snapshot?.height) {
            notes.append(depth)
        }
        return notes
    }
}
