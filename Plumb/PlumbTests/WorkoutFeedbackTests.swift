import Foundation
import Testing
@testable import Plumb

@MainActor
struct WorkoutFeedbackTests {
    @Test func choicesPersistAndHaveQuietDefaults() throws {
        let name = "PlumbFeedback-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = PlumbPreferences(defaults: defaults)
        #expect(preferences.hapticFeedback == .gentle)
        #expect(preferences.soundFeedback == .off)

        let model = WorkoutSessionModel(source: DemoPoseSource(), preferences: preferences)
        model.hapticFeedback = .off
        model.soundFeedback = .bright
        let reloaded = PlumbPreferences(defaults: defaults)
        #expect(reloaded.hapticFeedback == .off)
        #expect(reloaded.soundFeedback == .bright)
        #expect(WorkoutSessionModel(source: DemoPoseSource(), preferences: reloaded).soundFeedback == .bright)
    }

    @Test func turningHapticsOffSilencesWatchEvents() async throws {
        let name = "PlumbWatchFeedback-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = WorkoutSessionModel(source: DemoPoseSource(), preferences: PlumbPreferences(defaults: defaults))
        model.hapticFeedback = .off
        var sent: [WatchState] = []
        let sync = WatchSync(model: model) { sent.append($0) }
        await model.startPreview()
        await model.beginSet(countdown: 0)
        for _ in 0..<100 where sent.last?.stage != .capturing {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(sent.last?.stage == .capturing)
        #expect(sent.filter { $0.stage == .capturing }.allSatisfy { $0.haptic == .none })
        #expect(sync.current?.haptic == WatchHaptic.none)
        await model.cancel()
    }
}
