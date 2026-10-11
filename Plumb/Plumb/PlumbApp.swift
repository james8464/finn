import SwiftUI

@main
struct PlumbApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-plumb-ui-demo") {
                ContentView(source: DemoPoseSource(startError:
                    ProcessInfo.processInfo.arguments.contains("-plumb-ui-camera-unavailable")
                    ? .unavailable : nil), store: LocalSessionStore(
                    url: FileManager.default.temporaryDirectory
                        .appending(path: "PlumbDemo-\(UUID().uuidString)", directoryHint: .isDirectory)
                        .appending(path: "sessions.json")),
                            narrator: ComparisonNarrator(generator: DemoRecapGenerator()))
            } else {
                ContentView(source: CameraPoseSource.live())
            }
            #else
            ContentView(source: CameraPoseSource.live())
            #endif
        }
    }
}
