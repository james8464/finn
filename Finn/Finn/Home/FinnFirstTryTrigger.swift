// TEMPORARY: stands in for the real first-try flow, which replaces this whole file.
// Tapping Try Finn shows a placeholder that closes itself, then marks Finn as tried so Home shows
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
    /// Presents the placeholder while `isPresented`, then sets `hasTriedFinn` with a fade and a small
    /// spring (a plain fade with Reduce Motion).
    func finnFirstTryTrigger(isPresented: Binding<Bool>, hasTriedFinn: Binding<Bool>) -> some View {
        modifier(FinnFirstTryTrigger(isPresented: isPresented, hasTriedFinn: hasTriedFinn))
    }
}

private struct FinnFirstTryTrigger: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var hasTriedFinn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : HomeStyle.spring) { hasTriedFinn = true }
        } content: {
            FinnFirstTryPlaceholder(isPresented: $isPresented)
        }
    }
}

/// Just the name, then gone.
private struct FinnFirstTryPlaceholder: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: "Finn")
            .font(.largeTitle.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { HomeBackdrop() }
            .accessibilityIdentifier("finn.firstTryPlaceholder")
            .task {
                try? await Task.sleep(for: .milliseconds(800))
                withTransaction(\.disablesAnimations, reduceMotion) { isPresented = false }
            }
    }
}
