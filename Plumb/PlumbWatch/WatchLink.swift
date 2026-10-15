import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// the watch side of Plumb: shows the set the iPhone measures and sends Start set and Stop set.
/// The watch measures nothing; every number comes from the iPhone camera.
@Observable
@MainActor
final class WatchLink: NSObject, WCSessionDelegate {
    /// the latest screen from the iPhone; nil until one arrives
    private(set) var state: WatchState?
    private(set) var isPhoneReachable = false
    /// shown when a command did not reach the iPhone
    private(set) var notice: String?
    /// heart rate while the iPhone camera is open, when the person turned on Personalize with Health
    let heart = HeartRateSession()
    @ObservationIgnored private var isStarted = false

    func start() {
        guard !isStarted, WCSession.isSupported() else { return }
        isStarted = true
        heart.onHeartRate = { beatsPerMinute, date in
            let reading = WatchHeartRate(beatsPerMinute: beatsPerMinute, measuredAt: date.timeIntervalSince1970)
            let session = WCSession.default
            guard session.activationState == .activated, session.isReachable else { return }
            // a lost reading is replaced by the next one a few seconds later
            session.sendMessage(reading.message(), replyHandler: nil, errorHandler: nil)
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ command: WatchCommand) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            notice = String(localized: "Open Plumb on your iPhone, then try again.")
            return
        }
        notice = nil
        Self.deliver(command, on: session, link: self)
    }

    private func apply(_ incoming: WatchState, live: Bool) {
        guard incoming.isNewer(than: state) else { return }
        state = incoming
        notice = nil
        followHeartRate(incoming)
        // a saved application context is read later, maybe long after: only live states tap
        if live { Self.play(incoming.haptic) }
    }

    /// runs the workout session from the moment the camera opens until it closes
    private func followHeartRate(_ state: WatchState) {
        if state.measuresHeartRate && state.stage != .ready {
            Task { await heart.start() }
        } else {
            heart.stop()
        }
    }

    private func commandFailed() {
        notice = String(localized: "Your iPhone didn’t get that. Try again, or use the iPhone.")
    }

    private static func play(_ haptic: WatchHaptic) {
        let type: WKHapticType
        switch haptic {
        case .none: return
        case .rep: type = .click
        case .observation: type = .directionUp
        case .start: type = .start
        case .end: type = .stop
        }
        WKInterfaceDevice.current().play(type)
    }

    nonisolated private static func deliver(_ command: WatchCommand, on session: WCSession, link: WatchLink) {
        session.sendMessage(command.message(), replyHandler: nil) { _ in
            Task { @MainActor in link.commandFailed() }
        }
    }

    // MARK: WCSessionDelegate, called on a background queue

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
        Task { @MainActor [weak self] in self?.isPhoneReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let state = WatchState(message: message) else { return }
        Task { @MainActor [weak self] in self?.apply(state, live: true) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let state = WatchState(message: applicationContext) else { return }
        Task { @MainActor [weak self] in self?.apply(state, live: false) }
    }
}
