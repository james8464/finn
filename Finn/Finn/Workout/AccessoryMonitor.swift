import AVFAudio
import Foundation
import Observation

/// Notices AirPods or other headphones and a paired Apple Watch, so the setup screen can say what
/// each one adds (`AccessoryGuide`), and mirrors the set on the watch through `WatchBridge`.
@Observable
@MainActor
final class AccessoryMonitor {
    /// AirPods or other headphones are the current audio output.
    private(set) var headphonesConnected = false
    @ObservationIgnored private let watch: WatchBridge
    /// Kept for the app's lifetime; the observer holds this monitor weakly.
    @ObservationIgnored private var routeObserver: (any NSObjectProtocol)?

    /// Headphone ports. AirPlay is left out: a speaker across the room is not in the person's ears.
    private static let headphonePorts: Set<AVAudioSession.Port> = [
        .bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .headphones,
    ]

    /// Does nothing until `start`, so demo and test input never touch the watch or audio route.
    /// A default argument is evaluated outside the main actor, so the shared bridge is chosen here.
    init(watch: WatchBridge? = nil) {
        self.watch = watch ?? .shared
    }

    var status: AccessoryStatus {
        AccessoryStatus(headphonesConnected: headphonesConnected, watch: watch.connection)
    }

    /// Follows the audio route and the paired watch, and shows `model`'s sets on the watch.
    func start(model: WorkoutSessionModel, demoInput: Bool) {
        watch.start()
        watch.attach(to: model, demoInput: demoInput)
        refreshHeadphones()
        guard routeObserver == nil else {
            return
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHeadphones() }
        }
    }

    /// Reads where audio plays now. Finn never activates or reconfigures its audio session for this:
    /// spoken reps use their own session (`LiveAnnouncer`).
    func refreshHeadphones() {
        let connected = AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            Self.headphonePorts.contains($0.portType)
        }
        if connected != headphonesConnected {
            headphonesConnected = connected
        }
    }
}
