import AVFoundation
import Observation

/// what iOS allows for the camera, and how to ask. Live in the app; fixed in previews and for demo
/// input, which films nobody
struct TryFinnCameraAccess: Sendable {
    nonisolated enum Status: Equatable, Sendable {
        case notDetermined, authorized, denied, restricted
    }

    let status: @MainActor @Sendable () -> Status
    /// shows the iOS prompt; true when the person allows the camera
    let request: @MainActor @Sendable () async -> Bool

    static let live = TryFinnCameraAccess(status: {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }, request: {
        await AVCaptureDevice.requestAccess(for: .video)
    })

    static func fixed(_ status: Status) -> TryFinnCameraAccess {
        TryFinnCameraAccess(status: { status }, request: { status == .authorized })
    }

    /// demo and recorded input (`-finn-ui-demo`, `-finn-video-file`) never open the camera
    static var forThisLaunch: TryFinnCameraAccess {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-finn-ui-demo") || arguments.contains("-finn-video-file") {
            return .fixed(.authorized)
        }
        #endif
        return .live
    }
}

/// the Try Finn screen's state: which exercise the level gives, and whether the camera can open.
/// The camera is asked for when the person taps Try exercise, never before
@Observable
@MainActor
final class TryFinnViewModel {
    let exercise: TryFinnExercise
    /// nil until Try exercise is tapped; then what iOS said
    private(set) var blockedAccess: TryFinnCameraAccess.Status?
    private(set) var isRequesting = false
    @ObservationIgnored private let camera: TryFinnCameraAccess

    init(level: TrainingLevel?, camera: TryFinnCameraAccess) {
        exercise = .forLevel(TryFinnLevel(level))
        self.camera = camera
    }

    /// true when the camera may open now. Otherwise the screen explains why and offers Settings
    func tryExercise() async -> Bool {
        guard !isRequesting else { return false }
        switch camera.status() {
        case .authorized:
            blockedAccess = nil
            return true
        case .notDetermined:
            isRequesting = true
            let allowed = await camera.request()
            isRequesting = false
            blockedAccess = allowed ? nil : .denied
            return allowed
        case let status:
            blockedAccess = status
            return false
        }
    }

    /// back from Settings: an allowed camera clears the explanation, so Try exercise shows again
    func refreshAccess() {
        guard blockedAccess != nil else { return }
        if camera.status() == .authorized { blockedAccess = nil }
    }

    #if DEBUG
    /// previews start on the camera explanation
    func showBlocked(_ status: TryFinnCameraAccess.Status) { blockedAccess = status }
    #endif
}
