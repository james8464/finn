import Foundation
import SwiftUI
import Testing
import WidgetKit
@testable import Finn

/// What the widget reads must be exactly what the history saved, and nothing else.
struct WidgetSharingTests {
    private func sharedStore() -> (SharedSetStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "FinnWidgetTests-\(UUID().uuidString)")!
        return (SharedSetStore(defaults: defaults), defaults)
    }

    private func temporaryHistoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "FinnWidgetTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "sessions.json")
    }

    private func set(
        sessionID: UUID,
        at date: Date,
        reps: Int,
        exercise: ExerciseKind = .bodyweightSquat,
        partlyVisible: Bool? = nil
    ) -> SetSummary {
        let metrics = (1 ... max(reps, 0)).map {
            RepMetric(number: $0, startTime: Double($0), endTime: Double($0) + 1, relativeRange: 0.4)
        }
        return SetSummary(
            id: UUID(),
            sessionID: sessionID,
            capturedAt: date,
            bodySide: .left,
            analysis: SetAnalysis(reps: metrics, confidence: 0.9, rubricVersion: "test"),
            cue: nil,
            cueResponse: .unanswered,
            exercise: exercise,
            partlyVisible: partlyVisible
        )
    }

    @Test func snapshotRoundTripsThroughSharedDefaults() {
        let (store, _) = sharedStore()
        let snapshot = LastSetSnapshot(
            exerciseName: "Push-up",
            exerciseKey: "pushUp",
            reps: 9,
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
            partlyVisible: true
        )
        #expect(store.read() == nil)
        store.write(snapshot)
        #expect(store.read() == snapshot)
        store.write(nil)
        #expect(store.read() == nil)
    }

    @Test func latestSetIsTheMostRecentAcrossSessions() {
        let old = UUID(), recent = UUID()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let sessions = [
            WorkoutSessionSummary(id: recent, startedAt: base.addingTimeInterval(3_600), sets: [
                set(sessionID: recent, at: base.addingTimeInterval(3_600), reps: 7, exercise: .pullUp),
                set(
                    sessionID: recent,
                    at: base.addingTimeInterval(3_900),
                    reps: 5,
                    exercise: .pullUp,
                    partlyVisible: true
                ),
            ]),
            WorkoutSessionSummary(id: old, startedAt: base, sets: [
                set(sessionID: old, at: base, reps: 12),
            ]),
        ]
        let latest = LastSetSnapshot.latest(in: sessions)
        #expect(latest?.reps == 5)
        #expect(latest?.exerciseName == "Pull-up")
        #expect(latest?.exerciseKey == "pullUp")
        #expect(latest?.partlyVisible == true)
        #expect(latest?.capturedAt == base.addingTimeInterval(3_900))
        #expect(LastSetSnapshot.latest(in: []) == nil)
        #expect(LastSetSnapshot
            .latest(in: [WorkoutSessionSummary(id: old, startedAt: base, sets: [])]) == nil)
    }

    @Test func savingToHistoryPublishesTheSnapshotAndReloadsWidgets() throws {
        let url = temporaryHistoryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (shared, _) = sharedStore()
        let reloads = Reloads()
        let store = WidgetSharingSessionStore(
            base: LocalSessionStore(url: url),
            shared: shared,
            widgetsChanged: { reloads.increment() }
        )
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        try store.save(WorkoutSessionSummary(
            id: id,
            startedAt: date,
            sets: [set(sessionID: id, at: date, reps: 6)]
        ))
        #expect(shared.read()?.reps == 6)
        #expect(shared.read()?.exerciseName == "Squat")
        #expect(reloads.count == 1)

        // saving the same session again (a cue dismissed) changes nothing for the widget.
        try store.save(WorkoutSessionSummary(
            id: id,
            startedAt: date,
            sets: [set(sessionID: id, at: date, reps: 6)]
        ))
        #expect(reloads.count == 1)

        try store.deleteAll()
        #expect(shared.read() == nil)
        #expect(reloads.count == 2)
        #expect(try store.load().isEmpty)
    }

    @Test func deletingTheLatestSessionFallsBackToTheEarlierSet() throws {
        let url = temporaryHistoryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (shared, _) = sharedStore()
        let store = WidgetSharingSessionStore(
            base: LocalSessionStore(url: url),
            shared: shared,
            widgetsChanged: {}
        )
        let first = UUID(), second = UUID()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        try store.save(WorkoutSessionSummary(
            id: first,
            startedAt: base,
            sets: [set(sessionID: first, at: base, reps: 10)]
        ))
        try store.save(WorkoutSessionSummary(
            id: second,
            startedAt: base.addingTimeInterval(7_200),
            sets: [set(
                sessionID: second,
                at: base.addingTimeInterval(7_200),
                reps: 3
            )]
        ))
        #expect(shared.read()?.reps == 3)
        try store.delete(id: second)
        #expect(shared.read()?.reps == 10)
    }

    @Test func sharedSnapshotCarriesNoPoseOrHealthData() throws {
        let data = try JSONEncoder().encode(LastSetSnapshot(
            exerciseName: "Squat",
            exerciseKey: "bodyweightSquat",
            reps: 4,
            capturedAt: .now,
            partlyVisible: false
        ))
        let text = String(decoding: data, as: UTF8.self)
        for forbidden in ["joints", "heartRate", "PoseFrame", "video", "normalizedHipTravel"] {
            #expect(!text.contains(forbidden))
        }
    }

    @Test func deepLinkRoundTripsAndRejectsOtherURLs() {
        let withExercise = FinnDeepLink.startSet(exerciseKey: "pushUp")
        #expect(withExercise.url.absoluteString == "finn://start-set?exercise=pushUp")
        #expect(FinnDeepLink(withExercise.url) == withExercise)
        let plain = FinnDeepLink.startSet(exerciseKey: nil)
        #expect(FinnDeepLink(plain.url) == plain)
        #expect(FinnDeepLink(URL(string: "finn://start-set?exercise=")!) == plain)
        #expect(FinnDeepLink(URL(string: "https://example.com/start-set")!) == nil)
        #expect(FinnDeepLink(URL(string: "finn://history")!) == nil)
    }

    @Test func liveActivityExistsExactlyWhileTheSetRuns() {
        typealias Rules = SetLiveActivityRules
        #expect(Rules.step(from: .countdown(1), to: .capturing, exercise: .pushUp, reps: 0, isRunning: false)
            == .start(exercise: .pushUp, reps: 0))
        #expect(Rules.step(from: .capturing, to: .capturing, exercise: .pushUp, reps: 3, isRunning: true)
            == .update(reps: 3))
        #expect(Rules
            .step(from: .capturing, to: .analyzing, exercise: .pushUp, reps: 3, isRunning: true) == .end)
        #expect(Rules.step(from: .capturing, to: .ready, exercise: .pushUp, reps: 3, isRunning: true) == .end)
        #expect(Rules.step(from: .ready, to: .framing, exercise: .pushUp, reps: 0, isRunning: false) == .none)
        #expect(Rules.step(from: nil, to: .result, exercise: .pushUp, reps: 0, isRunning: false) == .none)
    }

    @Test func widgetDateLineNamesTodayAndYesterday() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(LastSetWidgetView.when(now.addingTimeInterval(-60), now: now).hasPrefix("Today "))
        #expect(LastSetWidgetView.when(now.addingTimeInterval(-86_400), now: now).hasPrefix("Yesterday "))
        #expect(!LastSetWidgetView.when(now.addingTimeInterval(-10 * 86_400), now: now).hasPrefix("Today"))
    }

    /// Renders the widget and Live Activity views to PNG files, for review without a device: in
    /// `FINN_WIDGET_RENDERS` when set, otherwise in the test process's temporary directory
    /// (`FinnWidgetRenders/`, printed below).
    @Test @MainActor func rendersWidgetPreviews() throws {
        let out = ProcessInfo.processInfo.environment["FINN_WIDGET_RENDERS"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appending(
                path: "FinnWidgetRenders",
                directoryHint: .isDirectory
            )
        print("Widget renders: \(out.path)")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = LastSetSnapshot(
            exerciseName: "Squat",
            exerciseKey: "bodyweightSquat",
            reps: 12,
            capturedAt: now.addingTimeInterval(-40 * 60),
            partlyVisible: false
        )
        // the activity's clock counts from the real present: a fixed date would render hours of set.
        let attributes = FinnSetActivityAttributes(
            exerciseName: "Squat",
            startedAt: Date.now.addingTimeInterval(-48),
            demoInput: false
        )
        let state = FinnSetActivityAttributes.ContentState(reps: 7)
        let renders: [(String, AnyView, CGSize)] = [
            (
                "widget-small",
                AnyView(LastSetWidgetView(snapshot: snapshot, family: .systemSmall, now: now)),
                CGSize(width: 170, height: 170)
            ),
            (
                "widget-medium",
                AnyView(LastSetWidgetView(snapshot: snapshot, family: .systemMedium, now: now)),
                CGSize(width: 364, height: 170)
            ),
            (
                "widget-small-empty",
                AnyView(LastSetWidgetView(snapshot: nil, family: .systemSmall, now: now)),
                CGSize(width: 170, height: 170)
            ),
            (
                "widget-medium-empty",
                AnyView(LastSetWidgetView(snapshot: nil, family: .systemMedium, now: now)),
                CGSize(width: 364, height: 170)
            ),
            (
                "live-activity-lock-screen",
                AnyView(SetActivityLockScreenView(attributes: attributes, state: state)),
                CGSize(width: 372, height: 110)
            ),
        ]
        for scheme in [ColorScheme.light, .dark] {
            for (name, view, size) in renders {
                let framed = view
                    .padding(16)
                    .frame(width: size.width, height: size.height)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: framed)
                renderer.scale = 3
                let image = try #require(renderer.uiImage)
                let data = try #require(image.pngData())
                try data.write(to: out.appending(path: "\(name)-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: out.path).count >= renders.count * 2)
    }
}

private final class Reloads: @unchecked Sendable {
    private(set) var count = 0
    func increment() {
        count += 1
    }
}
