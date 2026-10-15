import Foundation
import Testing
@testable import Finn

struct BadgeRulesTests {
    private let day: TimeInterval = 86_400
    private let origin = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func set(_ exercise: ExerciseKind = .bodyweightSquat, reps: Int, range: Double = 0.4,
                     at offset: TimeInterval, session: UUID = UUID(), cue: Cue? = nil,
                     issues: [SetIssue] = [], partlyVisible: Bool? = nil, side: BodySide = .left) -> SetSummary {
        let metrics = (0..<reps).map { index in
            RepMetric(number: index + 1, startTime: Double(index) * 2, endTime: Double(index) * 2 + 1.5,
                      relativeRange: range)
        }
        return SetSummary(id: UUID(), sessionID: session, capturedAt: origin.addingTimeInterval(offset),
                          bodySide: side, analysis: SetAnalysis(reps: metrics, confidence: 0.9, rubricVersion: "t"),
                          cue: cue, cueResponse: .unanswered, exercise: exercise, issues: issues,
                          partlyVisible: partlyVisible)
    }

    private func history(_ sets: [SetSummary]) -> [WorkoutSessionSummary] {
        var sessions: [UUID: WorkoutSessionSummary] = [:]
        for set in sets {
            var session = sessions[set.sessionID]
                ?? WorkoutSessionSummary(id: set.sessionID, startedAt: set.capturedAt, sets: [])
            session.sets.append(set)
            sessions[set.sessionID] = session
        }
        return Array(sessions.values)
    }

    private func kinds(_ badges: [EarnedBadge]) -> Set<BadgeKind> { Set(badges.map(\.kind)) }

    @Test func nothingWithoutAMeasuredSet() {
        #expect(BadgeRules.evaluate(history: []).isEmpty)
        let empty = history([set(reps: 0, at: 0)])
        #expect(BadgeRules.evaluate(history: empty).isEmpty)
    }

    @Test func firstSetIsDatedByTheEarliestSet() {
        let badges = BadgeRules.evaluate(history: history([set(reps: 5, at: day), set(reps: 3, at: 0)]))
        let first = badges.first { $0.kind == .firstSet }
        #expect(first?.earnedAt == origin)
        #expect(first?.detail.contains("3 squat reps") == true)
    }

    @Test func threeDaysNeedThreeDistinctDaysWithinAWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
// three sets on one day: no.
        let sameDay = history([set(reps: 5, at: 0), set(reps: 5, at: 3600), set(reps: 5, at: 7200)])
        #expect(!kinds(BadgeRules.evaluate(history: sameDay, calendar: calendar)).contains(.threeDaysInAWeek))
        // Three days spread over nine days: no.
        let spread = history([set(reps: 5, at: 0), set(reps: 5, at: 4 * day), set(reps: 5, at: 8 * day)])
        #expect(!kinds(BadgeRules.evaluate(history: spread, calendar: calendar)).contains(.threeDaysInAWeek))
        // Monday, Wednesday, Sunday: yes, dated by the third day.
        let week = history([set(reps: 5, at: 0), set(reps: 5, at: 2 * day), set(reps: 5, at: 6 * day)])
        let badge = BadgeRules.evaluate(history: week, calendar: calendar).first { $0.kind == .threeDaysInAWeek }
        #expect(badge?.earnedAt == origin.addingTimeInterval(6 * day))
    }

    @Test func cleanSetNeedsEnoughRepsFullyVisibleAndNoObservation() {
        let cue = Cue(kind: .rangeDecreased, repNumbers: [5, 6], earlierMedian: 0.4, laterMedian: 0.3,
                      observation: "Shorter", nextAction: "Keep it")
        let withCue = history([set(reps: 6, at: 0, cue: cue)])
        #expect(!kinds(BadgeRules.evaluate(history: withCue)).contains(.cleanSet))
        let tooShort = history([set(reps: SetComparison.minimumReps - 1, at: 0)])
        #expect(!kinds(BadgeRules.evaluate(history: tooShort)).contains(.cleanSet))
        let withIssue = history([set(reps: 6, at: 0, issues: [.shallowMovements])])
        #expect(!kinds(BadgeRules.evaluate(history: withIssue)).contains(.cleanSet))
        let partly = history([set(reps: 6, at: 0, partlyVisible: true)])
        #expect(!kinds(BadgeRules.evaluate(history: partly)).contains(.cleanSet))
        let clean = history([set(reps: SetComparison.minimumReps, at: 0)])
        #expect(kinds(BadgeRules.evaluate(history: clean)).contains(.cleanSet))
    }

    @Test func allSixNeedsEverySingleExercise() {
        let five = history(Array(ExerciseKind.allCases.prefix(5)).enumerated().map { index, kind in
            set(kind, reps: 3, at: Double(index) * 3600)
        })
        #expect(!kinds(BadgeRules.evaluate(history: five)).contains(.allSixExercises))
        let six = history(ExerciseKind.allCases.enumerated().map { index, kind in
            set(kind, reps: 3, at: Double(index) * 3600)
        })
        let badge = BadgeRules.evaluate(history: six).first { $0.kind == .allSixExercises }
        #expect(badge?.earnedAt == origin.addingTimeInterval(5 * 3600))
    }

    @Test func repRecordNeedsAnEarlierSetToBeat() {
        let single = history([set(reps: 12, at: 0)])
        #expect(!kinds(BadgeRules.evaluate(history: single)).contains(.repRecord(.bodyweightSquat)))
        let equal = history([set(reps: 8, at: 0), set(reps: 8, at: day)])
        #expect(!kinds(BadgeRules.evaluate(history: equal)).contains(.repRecord(.bodyweightSquat)))
        let fewer = history([set(reps: 8, at: 0), set(reps: 6, at: day)])
        #expect(!kinds(BadgeRules.evaluate(history: fewer)).contains(.repRecord(.bodyweightSquat)))
        let record = history([set(reps: 8, at: 0), set(reps: 9, at: day), set(.pushUp, reps: 20, at: 2 * day)])
        let badges = BadgeRules.evaluate(history: record)
        let squat = badges.first { $0.kind == .repRecord(.bodyweightSquat) }
        #expect(squat?.detail == "9 squat reps, up from 8 in your best earlier set.")
        // The push-up has one set only: a record is a comparison, not a count.
        #expect(!kinds(badges).contains(.repRecord(.pushUp)))
    }

    @Test func longerRangeFollowsTheComparisonRules() {
        let session = UUID()
// same session, same side, enough reps, +25%: yes.
        let longer = history([set(reps: 5, range: 0.40, at: 0, session: session),
                              set(reps: 5, range: 0.50, at: 300, session: session)])
        let badge = BadgeRules.evaluate(history: longer).first { $0.kind == .longerRange(.bodyweightSquat) }
        #expect(badge != nil)
        #expect(badge?.detail.contains("25%") == true)
        // +10% is within noise: no.
        let slight = history([set(reps: 5, range: 0.40, at: 0, session: session),
                              set(reps: 5, range: 0.44, at: 300, session: session)])
        #expect(!kinds(BadgeRules.evaluate(history: slight)).contains(.longerRange(.bodyweightSquat)))
        // Different sessions are not compared.
        let apart = history([set(reps: 5, range: 0.40, at: 0), set(reps: 5, range: 0.60, at: day)])
        #expect(!kinds(BadgeRules.evaluate(history: apart)).contains(.longerRange(.bodyweightSquat)))
        // A partly visible set never earns it.
        let partly = history([set(reps: 5, range: 0.40, at: 0, session: session),
                              set(reps: 5, range: 0.60, at: 300, session: session, partlyVisible: true)])
        #expect(!kinds(BadgeRules.evaluate(history: partly)).contains(.longerRange(.bodyweightSquat)))
    }

    @MainActor @Test func ledgerGivesEachBadgeOnceAndKeepsIt() throws {
        let store = MemoryBadgeStore()
        let ledger = BadgeLedger(store: store)
        let a = set(reps: 5, at: 0)
        let first = history([a])
        let fresh = ledger.update(history: first, celebrating: a.id)
        #expect(fresh.map(\.kind) == [.firstSet, .cleanSet] || fresh.map(\.kind) == [.cleanSet, .firstSet])
        #expect(ledger.justEarned.count == 2)
        // The same history again: nothing new, nothing to celebrate.
        ledger.acknowledge()
        #expect(ledger.update(history: first, celebrating: a.id).isEmpty)
        #expect(ledger.justEarned.isEmpty)
        #expect(ledger.count == 2)
        // A record set adds exactly one badge, and that set celebrates it.
        let b = set(reps: 7, at: day)
        let more = history([a, b])
        #expect(ledger.update(history: more, celebrating: b.id).map(\.kind) == [.repRecord(.bodyweightSquat)])
        #expect(ledger.justEarned.map(\.kind) == [.repRecord(.bodyweightSquat)])
        // Saved: a new ledger on the same store knows them, and the history shrinking takes nothing away.
        let reloaded = BadgeLedger(store: store)
        #expect(reloaded.count == 3)
        #expect(reloaded.update(history: []).isEmpty)
        #expect(reloaded.count == 3)
        #expect(try store.load().count == 3)
    }

    /// First launch after an update: what the history already supports is written down without a
    /// fête, and a later set that earns nothing shows nothing. On 15 October a 14-rep push-up set
    /// announced "First set, 7 pull-up reps" and a 27-rep push-up record, both from older sets.
    @MainActor @Test func badgesFoundAtLaunchAreRecordedWithoutCelebration() {
        let ledger = BadgeLedger(store: MemoryBadgeStore())
        let older = [set(.pullUp, reps: 7, at: 0), set(.pushUp, reps: 19, at: day), set(.pushUp, reps: 27, at: 2 * day)]
        let found = ledger.update(history: history(older))
        #expect(kinds(found).isSuperset(of: [.firstSet, .repRecord(.pushUp)]))
        #expect(ledger.justEarned.isEmpty)
        let pushUps14 = set(.pushUp, reps: 14, at: 3 * day)
        #expect(ledger.update(history: history(older + [pushUps14]), celebrating: pushUps14.id).isEmpty)
        #expect(ledger.justEarned.isEmpty)
        #expect(ledger.has(.repRecord(.pushUp)))
    }

    @MainActor @Test func aSetCelebratesOnlyTheBadgesItEarnedItself() {
        let ledger = BadgeLedger(store: MemoryBadgeStore())
        let a = set(reps: 5, at: 0)
        ledger.update(history: history([a]), celebrating: a.id)
        #expect(kinds(ledger.justEarned) == [.firstSet, .cleanSet])
        let b = set(reps: 7, at: day)
        ledger.update(history: history([a, b]), celebrating: b.id)
        #expect(kinds(ledger.justEarned) == [.repRecord(.bodyweightSquat)])
    }

    /// A record is celebrated by the set that beat it, never by a later set that merely finds it in
    /// the history.
    @MainActor @Test func aRecordIsCelebratedOnlyByTheSetThatBeatsIt() {
        let a = set(reps: 5, at: 0), b = set(reps: 9, at: day), c = set(reps: 6, at: 2 * day)
        let quiet = BadgeLedger(store: MemoryBadgeStore())
        quiet.update(history: history([a, b, c]), celebrating: c.id)
        #expect(quiet.has(.repRecord(.bodyweightSquat)))
        #expect(!kinds(quiet.justEarned).contains(.repRecord(.bodyweightSquat)))
        let loud = BadgeLedger(store: MemoryBadgeStore())
        loud.update(history: history([a, b]), celebrating: b.id)
        #expect(kinds(loud.justEarned).contains(.repRecord(.bodyweightSquat)))
    }

    @MainActor @Test func resetForgetsEverything() throws {
        let store = MemoryBadgeStore()
        let ledger = BadgeLedger(store: store)
        ledger.update(history: history([set(reps: 5, at: 0)]))
        ledger.reset()
        #expect(ledger.count == 0)
        #expect(try store.load().isEmpty)
    }

    @Test func badgeKindsRoundTripThroughJSON() throws {
        let badges = [EarnedBadge(kind: .repRecord(.pullUp), earnedAt: origin, detail: "x"),
                      EarnedBadge(kind: .longerRange(.staticLunge), earnedAt: origin, detail: "y"),
                      EarnedBadge(kind: .threeDaysInAWeek, earnedAt: origin, detail: "z")]
        let data = try JSONEncoder().encode(badges)
        #expect(try JSONDecoder().decode([EarnedBadge].self, from: data) == badges)
        #expect(BadgeKind.all.count == 4 + 2 * ExerciseKind.allCases.count)
    }
}
