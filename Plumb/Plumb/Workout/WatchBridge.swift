import Foundation
import Observation
import WatchConnectivity

/// Links Plumb on the iPhone with Plumb on a paired Apple Watch. The watch shows the set the iPhone
/// measures, taps the wrist on each rep, and can start or stop the set; it measures nothing itself.
/// Only the stage, rep count, short observation text and result line go to the watch, never video
/// or pose points. `WatchSync` decides what to send; this class only carries it.
@Observable
@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    /// What the iPhone knows about the paired watch.
    private(set) var connection = WatchConnection.none
    @ObservationIgnored private var sync: WatchSync?
    @ObservationIgnored private var isStarted = false

    private override init() {
        super.init()
    }

    /// Whether this build carries the Plumb watch app (embedded in the app's Watch folder). Until the
    /// PlumbWatch target is in the Xcode project, nothing talks to the watch and no setup line asks
    /// the person to install an app that does not exist.
    nonisolated static var isWatchAppBundled: Bool {
        FileManager.default.fileExists(atPath: Bundle.main.bundleURL.appending(path: "Watch").path)
    }

    /// Activates WatchConnectivity once. Does nothing where it is unsupported or without a watch app.
    func start() {
        guard !isStarted, Self.isWatchAppBundled, WCSession.isSupported() else { return }
        isStarted = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Shows `model`'s sets on the watch and lets the watch start and stop them.
    func attach(to model: WorkoutSessionModel, demoInput: Bool) {
        guard sync == nil else { return }
        sync = WatchSync(model: model, demoInput: demoInput) { [weak self] state in
            self?.deliver(state)
        }
    }

    private func deliver(_ state: WatchState) {
        guard isStarted else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        if session.isReachable {
            Self.sendLive(state, on: session)
        } else {
            Self.keepForLater(state, on: session)
        }
    }

    private func update(_ new: WatchConnection) {
        guard new != connection else { return }
        connection = new
        // A watch that just opened Plumb, or a session that just activated, gets the current screen.
        if let current = sync?.current { deliver(current) }
    }

    /// Sends a state the watch shows at once, with its tap. If the watch stops listening on the way,
    /// the state becomes the latest application context instead.
    nonisolated private static func sendLive(_ state: WatchState, on session: WCSession) {
        session.sendMessage(state.message(), replyHandler: nil) { _ in
            WatchBridge.keepForLater(state, on: WCSession.default)
        }
    }

    /// Replaces the application context, which the watch reads when Plumb opens there. Only the newest
    /// state matters, so nothing queues up, and a state read later never taps the wrist.
    nonisolated private static func keepForLater(_ state: WatchState, on session: WCSession) {
        var quiet = state
        quiet.haptic = .none
        try? session.updateApplicationContext(quiet.message())
    }

    nonisolated private static func readConnection(of session: WCSession) -> WatchConnection {
        guard session.activationState == .activated else { return .none }
        return WatchConnection(isPaired: session.isPaired, isAppInstalled: session.isWatchAppInstalled,
                               isReachable: session.isReachable)
    }

    // MARK: WCSessionDelegate, called on a background queue

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let connection = Self.readConnection(of: session)
        Task { @MainActor [weak self] in self?.update(connection) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // The person switched to another watch: start a session with that one.
        WCSession.default.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let connection = Self.readConnection(of: session)
        Task { @MainActor [weak self] in self?.update(connection) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let connection = Self.readConnection(of: session)
        Task { @MainActor [weak self] in self?.update(connection) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let heartRate = WatchHeartRate(message: message) {
            Task { @MainActor [weak self] in self?.sync?.handle(heartRate) }
            return
        }
        guard let command = WatchCommand(message: message) else { return }
        Task { @MainActor [weak self] in self?.sync?.handle(command) }
    }
}
