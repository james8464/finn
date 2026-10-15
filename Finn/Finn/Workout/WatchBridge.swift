import Foundation
import Observation
import WatchConnectivity

/// Sends the phone's measured set state and short coaching lines to a paired Apple Watch.
/// Rhythm taps are timed on the Watch; no video or pose points cross this link.
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

    /// Whether this build carries the Finn watch app (embedded in the app's Watch folder). Until the
    /// FinnWatch target is in the Xcode project, nothing talks to the watch and no setup line asks
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

    /// Mirrors `model`'s sets and coaching lines on the watch.
    func attach(to model: WorkoutSessionModel, demoInput: Bool) {
        guard sync == nil else { return }
        sync = WatchSync(model: model, demoInput: demoInput) { [weak self] state in
            self?.deliver(state)
        }
    }

    private func deliver(_ state: WatchState) {
        guard isStarted else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired else { return }
// keep the latest screen even while the watch is reachable: a live message can be lost
        // when either app moves between foreground and background. Context replaces older states.
        Self.keepForLater(state, on: session)
        if session.isReachable { Self.sendLive(state, on: session) }
    }

    private func update(_ new: WatchConnection) {
        guard new != connection else { return }
        connection = new
// a watch that just opened Finn, or a session that just activated, gets the current screen.
        if let current = sync?.current { deliver(current) }
    }

    /// Sends a state the watch shows at once. Application context was already updated above, so a
    /// delayed failure cannot replace a newer state with an older one.
    nonisolated private static func sendLive(_ state: WatchState, on session: WCSession) {
        session.sendMessage(state.message(), replyHandler: nil, errorHandler: nil)
    }

    /// Replaces the application context, which the watch reads when Finn opens there. Only the newest
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
// the person switched to another watch: start a session with that one.
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
    }
}
