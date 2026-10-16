import SwiftUI

@main
struct FinnWatchApp: App {
    @State private var link = WatchLink()

    var body: some Scene {
        WindowGroup {
            WatchSetView(link: link)
                .task { link.start() }
        }
    }
}
