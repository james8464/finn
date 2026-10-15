import Foundation
import SwiftUI
import Testing
@testable import Finn

/// The Siri side of Finn: what "How did my last set go" says, what "Start a set" asks the app to
/// do, and when the app may act on it.
nonisolated struct IntentsTests {
    private static let now = Date(timeIntervalSince1970: 1_792_051_200) // 15 Oct 2026, 10:00 CEST
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    private func set(_ exercise: ExerciseKind = .bodyweightSquat, reps: Int = 8, minutesAgo: Double,
                     observation: String? = nil, response: CueResponse = .unanswered,
                     partlyVisible: Bool? = nil) -> SetSummary {
        let metrics = (0..<reps).map {
            RepMetric(number: $0 + 1, startTime: Double($0) * 3, endTime: Double($0) * 3 + 2, relativeRange: 0.4)
        }
        let cue = observation.map {
            Cue(kind: .rangeDecreased, repNumbers: [5, 6], earlierMedian: 0.4, laterMedian: 0.3,
                observation: $0, nextAction: "Pause a breath at the bottom of the next rep.")
        }
        return SetSummary(id: UUID(), sessionID: UUID(),
                          capturedAt: Self.now.addingTimeInterval(-minutesAgo * 60), bodySide: .left,
                          analysis: SetAnalysis(reps: metrics, confidence: 0.9, rubricVersion: SquatRubric.version),
                          cue: cue, cueResponse: response, exercise: exercise, partlyVisible: partlyVisible)
    }

    private func sessions(_ groups: [SetSummary]...) -> [WorkoutSessionSummary] {
        groups.map { sets in
            WorkoutSessionSummary(id: UUID(), startedAt: sets.map(\.capturedAt).min() ?? Self.now, sets: sets)
        }
    }

    // MARK: Last set

    @Test func emptyHistoryHasNoReport() {
        #expect(LastSetReport.latest(in: []) == nil)
        #expect(LastSetReport.latest(in: sessions([])) == nil)
    }

    @Test func picksTheMostRecentSetAcrossSessions() {
        let older = set(.pushUp, reps: 12, minutesAgo: 60 * 24)
        let latest = set(.pullUp, reps: 5, minutesAgo: 20, observation: "Chin passed the hands on 4 of 5 reps.")
        let middle = set(.bodyweightSquat, reps: 9, minutesAgo: 30)
// sessions are listed newest first in the app, but the report must not rely on that.
        let report = LastSetReport.latest(in: sessions([older], [middle, latest]))
        #expect(report?.exercise == .pullUp)
        #expect(report?.reps == 5)
        #expect(report?.observation == "Chin passed the hands on 4 of 5 reps.")
    }

    @Test func spokenSentenceGivesExerciseRepsTimeAndObservationWordForWord() {
        let note = "Squat depth was shallower on reps 5 and 6 than on your first reps."
        let report = LastSetReport.latest(in: sessions([set(reps: 8, minutesAgo: 20, observation: note)]))!
        let spoken = report.spoken(now: Self.now, calendar: Self.calendar)
        #expect(spoken == "Your last set in Finn: Squat, 8 measured reps, today at 09:40. Finn noted: \(note)")
    }

    @Test func singleRepAndYesterdayAreWorded() {
        let report = LastSetReport.latest(in: sessions([set(.pushUp, reps: 1, minutesAgo: 60 * 20)]))!
        #expect(report.repsText == "1 measured rep")
        #expect(report.whenText(now: Self.now, calendar: Self.calendar) == "yesterday at 14:00")
    }

    @Test func olderSetsNameTheDay() {
        let report = LastSetReport.latest(in: sessions([set(minutesAgo: 60 * 24 * 3)]))!
        #expect(report.whenText(now: Self.now, calendar: Self.calendar) == "12 Oct at 10:00")
    }

    @Test func noObservationIsSaidPlainly() {
        let report = LastSetReport.latest(in: sessions([set(minutesAgo: 5)]))!
        #expect(report.observation == nil)
        #expect(report.spoken(now: Self.now, calendar: Self.calendar)
                == "Your last set in Finn: Squat, 8 measured reps, today at 09:55. No clear observation in that set.")
    }

    @Test func dismissedObservationIsNotRepeated() {
        let report = LastSetReport.latest(in: sessions([
            set(minutesAgo: 5, observation: "Torso leaned further forward at the end.", response: .notRelevant)
        ]))!
        #expect(report.observation == nil)
        #expect(report.observationText == "No clear observation in that set.")
    }

    @Test func partlyVisibleSetExplainsTheMissingObservation() {
        let report = LastSetReport.latest(in: sessions([set(minutesAgo: 5, partlyVisible: true)]))!
        #expect(report.observationText.contains("only part of the set"))
    }

    @Test func intentAnswersFromTheStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FinnIntentsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = LocalSessionStore(url: directory.appending(path: "sessions.json"))
        defer { try? FileManager.default.removeItem(at: directory) }

        let (emptyDialog, emptyContent) = LastSetIntent.answer(from: store, now: Self.now)
        #expect(emptyDialog == LastSetReport.nothingYet)
        #expect(emptyContent == .nothingYet)

        let recorded = set(.staticLunge, reps: 6, minutesAgo: 10,
                           observation: "Front knee bent less on the last two reps.")
        let session = WorkoutSessionSummary(id: recorded.sessionID, startedAt: recorded.capturedAt,
                                            sets: [recorded])
        try store.save(session)
        let (dialog, content) = LastSetIntent.answer(from: store, now: Self.now)
        #expect(dialog.hasPrefix("Your last set in Finn: Static lunge, 6 measured reps,"))
        #expect(dialog.hasSuffix("Finn noted: Front knee bent less on the last two reps."))
        guard case .report(let report) = content else { Issue.record("expected a report"); return }
        #expect(report.exercise == .staticLunge)
    }

    @Test func unreadableStoreIsSaidNotGuessed() {
        let (dialog, content) = LastSetIntent.answer(from: FailingStore(), now: Self.now)
        #expect(dialog == LastSetReport.unavailable)
        #expect(content == .unavailable)
    }

    // MARK: Start a set and history

    @Test func everyExerciseIsASiriChoiceAndBack() {
        for kind in ExerciseKind.allCases {
            let choice = ExerciseChoice(kind)
            #expect(choice.kind == kind)
            #expect(ExerciseChoice.caseDisplayRepresentations[choice] != nil, "\(kind) has no Siri name")
        }
        #expect(ExerciseChoice.allCases.count == ExerciseKind.allCases.count)
        #expect(ExerciseChoice.caseDisplayRepresentations.count == ExerciseChoice.allCases.count)
    }

    @Test func startSetIntentCarriesItsExercise() {
        #expect(StartSetIntent(exercise: .pushUp).exercise.kind == .pushUp)
        #expect(StartSetIntent(exercise: .stiffLegDeadlift).exercise.kind == .stiffLegDeadlift)
    }

    @Test func aSetInProgressIsNeverInterrupted() {
        let start = SiriLaunchRequests.Request.startSet(.bodyweightSquat)
        #expect(SiriLaunchRequests.canApply(start, at: .ready))
        #expect(SiriLaunchRequests.canApply(start, at: .result))
        for stage in [WorkoutStage.openingCamera, .framing, .countdown(2), .capturing, .analyzing,
                      .error(.permissionDenied)] {
            #expect(!SiriLaunchRequests.canApply(start, at: stage), "\(stage)")
        }
        #expect(SiriLaunchRequests.canApply(.showHistory, at: .ready))
        #expect(!SiriLaunchRequests.canApply(.showHistory, at: .result))
    }

    /// Draws the Siri card to a PNG next to the test results, for a look without a device.
    @Test @MainActor func snippetRenders() throws {
        let report = LastSetReport.latest(in: sessions([
            set(reps: 8, minutesAgo: 20, observation: "Squat depth was shallower on reps 5 and 6 than on your first reps.")
        ]))!
        let view = LastSetSnippet(content: .report(report), now: Self.now)
            .frame(width: 360)
            .background(Color(uiColor: .systemBackground))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try #require(renderer.uiImage)
        #expect(image.size.width == 360)
        #expect(image.size.height > 80)
        let data = try #require(image.pngData())
        Attachment.record(data, named: "last-set-snippet.png")
        if let path = ProcessInfo.processInfo.environment["FINN_SNIPPET_PNG"] {
            try data.write(to: URL(fileURLWithPath: path))
        }
    }
}

nonisolated private struct FailingStore: SessionStoring {
    struct Locked: Error {}
    func load() throws -> [WorkoutSessionSummary] { throw Locked() }
    func save(_ session: WorkoutSessionSummary) throws { throw Locked() }
    func delete(id: UUID) throws { throw Locked() }
    func deleteAll() throws { throw Locked() }
    func recoverCorruptStore() throws -> URL { throw Locked() }
}
