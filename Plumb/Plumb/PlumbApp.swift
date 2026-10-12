import SwiftUI

@main
struct PlumbApp: App {
    #if DEBUG
    private static func argument(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    private static func recordedPoses() -> [PoseFrame]? {
        guard let path = argument(after: "-plumb-video-poses"),
              let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode([PoseFrame].self, from: data)
    }
    #endif

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-plumb-ui-demo") {
                ContentView(source: DemoPoseSource(startError:
                    ProcessInfo.processInfo.arguments.contains("-plumb-ui-camera-unavailable")
                    ? .unavailable : nil,
                    profileDeviation: ProcessInfo.processInfo.arguments
                        .contains("-plumb-ui-demo-front-view") ? 75 : nil), store: LocalSessionStore(
                    url: FileManager.default.temporaryDirectory
                        .appending(path: "PlumbDemo-\(UUID().uuidString)", directoryHint: .isDirectory)
                        .appending(path: "sessions.json")),
                            narrator: ComparisonNarrator(generator: DemoRecapGenerator()),
                            exerciseClassifier: ProcessInfo.processInfo.arguments
                                .contains("-plumb-ui-demo-recognition") ? DemoExerciseClassifier() : nil,
                            preferences: PlumbPreferences(defaults: UserDefaults(
                                suiteName: "PlumbDemo-\(UUID().uuidString)") ?? .standard))
            } else if let path = Self.argument(after: "-plumb-video-file") {
                ContentView(source: VideoFilePoseSource(url: URL(fileURLWithPath: path),
                                                        recordedPoses: Self.recordedPoses()),
                            store: LocalSessionStore(url: FileManager.default.temporaryDirectory
                                .appending(path: "PlumbVideo-\(UUID().uuidString)", directoryHint: .isDirectory)
                                .appending(path: "sessions.json")))
            } else {
                ContentView(source: CameraPoseSource.live())
            }
            #else
            ContentView(source: CameraPoseSource.live())
            #endif
        }
    }
}
