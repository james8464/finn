import SwiftUI

@main
struct PlumbApp: App {
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
            } else {
                ContentView(source: CameraPoseSource.live())
            }
            #else
            ContentView(source: CameraPoseSource.live())
            #endif
        }
    }
}
