import SwiftUI

@main
struct PlumbApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-plumb-ui-demo") {
                ContentView(source: DemoPoseSource(),
                            narrator: ComparisonNarrator(generator: DemoRecapGenerator()))
            } else {
                ContentView(source: CameraPoseSource.live())
            }
        }
    }
}
