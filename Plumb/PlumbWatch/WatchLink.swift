import Foundation
import Observation
import WatchConnectivity
import WatchKit

nonisolated enum WatchNotice: Equatable {
    case workoutPermission
    case workoutUnavailable
}

/// The Watch mirrors one short iPhone coaching line and owns only its optional pacing clock.
@Observable
@MainActor
final class WatchLink: NSObject, WCSessionDelegate {
    private(set) var state: WatchState?
    private(set) var isPhoneReachable = false
    private(set) var isLiveCapture = false
    private(set) var notice: WatchNotice?
    private(set) var rhythmEnabled: Bool
    private(set) var rhythmInterval: Int
    let workout = RhythmWorkoutSession()

    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var clock: WatchRhythmClock
    @ObservationIgnored private var rhythmArmed = false
    @ObservationIgnored private var lastPhoneStateAt = 0.0
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var startingWorkout = false
    @ObservationIgnored private var rhythmGeneration = 0

    override init() {
        let defaults = UserDefaults.standard
        rhythmEnabled = defaults.bool(forKey: "plumb.watch.rhythm")
        let stored = defaults.integer(forKey: "plumb.watch.rhythmInterval")
        let interval = [2, 3, 4, 5].contains(stored) ? stored : 3
        rhythmInterval = interval
        clock = WatchRhythmClock(interval: interval)
        super.init()
    }

    func start() {
        guard !isStarted, WCSession.isSupported() else { return }
        isStarted = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                self?.tick()
            }
        }
    }

    func setRhythmEnabled(_ enabled: Bool) async {
        if enabled {
            let permission = await workout.requestPermission()
            guard WatchRhythmPolicy.canEnable(permissionGranted: permission) else {
                rhythmEnabled = false
                UserDefaults.standard.set(false, forKey: "plumb.watch.rhythm")
                notice = .workoutPermission
                return
            }
        }
        rhythmEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "plumb.watch.rhythm")
        notice = nil
        if enabled { followCapture() } else { stopRhythm() }
    }

    func setRhythmInterval(_ interval: Int) {
        guard [2, 3, 4, 5].contains(interval) else { return }
        rhythmInterval = interval
        UserDefaults.standard.set(interval, forKey: "plumb.watch.rhythmInterval")
        clock = WatchRhythmClock(interval: interval)
        rhythmArmed = false
        followCapture()
    }

    private func apply(_ incoming: WatchState, live: Bool) {
        let now = Date().timeIntervalSince1970
        let fresh = incoming.isFreshForLive(now: now)
        guard incoming.isNewer(than: state) else {
            // Context and a live message may arrive in either order with the same timestamp.
            // The live copy still confirms liveness; it does not replay a state or tap.
            if live, incoming.matchesShownStateForLive(state, now: now) {
                lastPhoneStateAt = ProcessInfo.processInfo.systemUptime
                isLiveCapture = incoming.stage == .capturing
                followCapture()
            }
            return
        }
        let previousSetID = state?.setID
        state = incoming
        if fresh { lastPhoneStateAt = ProcessInfo.processInfo.systemUptime }
        isLiveCapture = fresh && incoming.stage == .capturing
        if incoming.stage == .capturing, previousSetID != incoming.setID {
            clock.stop()
            rhythmArmed = false
        }
        if isLiveCapture { followCapture() }
        else { stopRhythm() }
    }

    private func followCapture() {
        guard let state, isLiveCapture, isPhoneReachable,
              rhythmEnabled, state.hapticsEnabled else {
            stopRhythm()
            return
        }
        if rhythmArmed && workout.isRunning { return }
        guard !startingWorkout else { return }
        startingWorkout = true
        let startGeneration = rhythmGeneration
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.startingWorkout = false
                if startGeneration != self.rhythmGeneration { self.followCapture() }
            }
            let started = await self.workout.start()
            guard startGeneration == self.rhythmGeneration else { return }
            guard self.isLiveCapture, self.isPhoneReachable,
                  self.rhythmEnabled, self.state?.hapticsEnabled == true else {
                self.workout.stop()
                return
            }
            guard started else {
                self.rhythmEnabled = false
                UserDefaults.standard.set(false, forKey: "plumb.watch.rhythm")
                self.notice = .workoutUnavailable
                return
            }
            if !self.rhythmArmed {
                self.clock.resume(now: ProcessInfo.processInfo.systemUptime)
                self.rhythmArmed = true
            }
        }
    }

    private func stopRhythm() {
        rhythmGeneration += 1
        clock.stop()
        rhythmArmed = false
        workout.stop()
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if isLiveCapture && now - lastPhoneStateAt >= 15 {
            isLiveCapture = false
            stopRhythm()
        }
        guard let state, WatchRhythmPolicy.canTap(enabled: rhythmEnabled,
                                                  masterHapticsEnabled: state.hapticsEnabled,
                                                  workoutRunning: workout.isRunning,
                                                  capturing: isLiveCapture) else { return }
        if clock.shouldTap(now: now, lastPhoneStateAt: lastPhoneStateAt, reachable: isPhoneReachable) {
            WKInterfaceDevice.current().play(.click)
        } else if !isPhoneReachable || now - lastPhoneStateAt >= 15 {
            stopRhythm()
        }
    }

    // WatchConnectivity delegates arrive on a background queue.
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let reachable = session.isReachable
        let saved = WatchState(message: session.receivedApplicationContext)
        let now = Date().timeIntervalSince1970
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = reachable
            if let saved, !saved.isStale(now: now) { self?.apply(saved, live: false) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = reachable
            if !reachable {
                self?.isLiveCapture = false
                self?.stopRhythm()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let incoming = WatchState(message: message) else { return }
        Task { @MainActor [weak self] in self?.apply(incoming, live: true) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let incoming = WatchState(message: applicationContext) else { return }
        let now = Date().timeIntervalSince1970
        Task { @MainActor [weak self] in
            if !incoming.isStale(now: now) { self?.apply(incoming, live: false) }
        }
    }
}
