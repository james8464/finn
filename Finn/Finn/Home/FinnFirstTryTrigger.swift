// TEMPORARY: the first-try trigger. Try Finn now opens the real flow (`TryFinn/`); this file keeps
// the key and the name Home uses. Once a set has started, Finn is marked as tried so Home shows
// the coach card. To remove: delete this file, `.finnFirstTryTrigger` in `DashboardView` and the
// `hasTriedFinn` lines in `ContentView`. Replay onboarding (profile) resets it.
import SwiftUI

/// Whether this person has tried Finn. Kept across launches; Replay onboarding resets it.
enum FinnFirstTry {
    static let key = "finn.hasTriedFinn"
    /// UI-test demo launches use a throwaway store, so every run starts on Try Finn.
    static let defaults: UserDefaults = ProcessInfo.processInfo.arguments.contains("-finn-ui-demo")
        ? UserDefaults(suiteName: "FinnDemo-\(UUID().uuidString)") ?? .standard
        : .standard
}

extension View {
    /// Presents Try Finn (`TryFinn/`) while `isPresented`; a started set then sets `hasTriedFinn`.
    func finnFirstTryTrigger(isPresented: Binding<Bool>, hasTriedFinn: Binding<Bool>) -> some View {
        tryFinn(isPresented: isPresented, hasTriedFinn: hasTriedFinn)
    }
}
