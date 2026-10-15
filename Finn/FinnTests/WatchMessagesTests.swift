import Foundation
import Testing
@testable import Finn

nonisolated struct WatchMessagesTests {
    private let full = WatchState(stage: .capturing, countdown: 0, exercise: "Squat", reps: 5,
                                  caption: "Rep 5 was faster than your first reps", haptic: .observation,
                                  summary: nil, wristControls: true, handsFree: true, demoInput: false,
                                  sentAt: 1_791_000_000.25)

    @Test func everyStateRoundTrips() {
        for stage in WatchStage.allCases {
            for haptic in WatchHaptic.allCases {
                var state = full
                state.stage = stage
                state.haptic = haptic
                state.countdown = stage == .countdown ? 3 : 0
                state.summary = stage == .result ? "6 reps measured." : nil
                #expect(WatchState(message: state.message()) == state)
            }
        }
        let empty = WatchState()
        #expect(WatchState(message: empty.message()) == empty)
    }

    /// WatchConnectivity carries property lists only: the message must serialise, nil values left out.
    @Test func stateIsAPropertyListAndSurvivesSerialization() throws {
        for state in [full, WatchState(stage: .result, exercise: "Push-up", reps: 1, summary: "1 rep measured.",
                                       wristControls: false, demoInput: true, sentAt: 12)] {
            let message = state.message()
            #expect(!message.values.contains { $0 is NSNull })
            let data = try PropertyListSerialization.data(fromPropertyList: message, format: .binary, options: 0)
            let decoded = try #require(
                try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            #expect(WatchState(message: decoded) == state)
        }
        var noCaption = full
        noCaption.caption = nil
        #expect(noCaption.message()[WatchMessageKey.caption] == nil)
        #expect(noCaption.message()[WatchMessageKey.summary] == nil)
    }

    @Test func commandsRoundTripAndAreNotStates() throws {
        for command in WatchCommand.allCases {
            let message = command.message()
            #expect(WatchCommand(message: message) == command)
            #expect(WatchState(message: message) == nil)
            _ = try PropertyListSerialization.data(fromPropertyList: message, format: .binary, options: 0)
        }
        #expect(WatchCommand(message: full.message()) == nil)
    }

    @Test func unknownOrBrokenMessagesAreIgnored() {
        #expect(WatchState(message: [:]) == nil)
        #expect(WatchState(message: ["type": "state", "stage": "warmingUp"]) == nil)
        #expect(WatchCommand(message: ["type": "command", "command": "pause"]) == nil)
        #expect(WatchCommand(message: ["command": "startSet"]) == nil)
        // A newer phone may add keys or haptics; the watch keeps what it knows.
        let tolerant = WatchState(message: ["type": "state", "v": 2, "stage": "capturing", "reps": 4.0,
                                            "haptic": "doubleTap", "extra": "ignored"])
        #expect(tolerant == WatchState(stage: .capturing, reps: 4))
    }

    @Test func onlyANewerStateReplacesTheScreen() {
        var older = full
        older.sentAt = full.sentAt - 1
        #expect(full.isNewer(than: nil))
        #expect(full.isNewer(than: older))
        #expect(!older.isNewer(than: full))
        #expect(!full.isNewer(than: full))
    }

    @Test func matchingLiveMessageRefreshesOnlyWhileFresh() {
        #expect(full.matchesShownStateForLive(full, now: full.sentAt + 2))
        #expect(!full.matchesShownStateForLive(full, now: full.sentAt + 15))
        #expect(!full.matchesShownStateForLive(nil, now: full.sentAt + 2))
        var different = full
        different.reps += 1
        #expect(!different.matchesShownStateForLive(full, now: full.sentAt + 2))
    }

    @Test func aSavedStateFromLongAgoIsStale() {
        #expect(!full.isStale(now: full.sentAt + 30))
        #expect(full.isStale(now: full.sentAt + WatchState.staleAfter + 1))
    }

    @Test func coachingStateRoundTripsAndOldMessagesStillLoad() {
        var coached = full
        coached.setID = "set-1"
        coached.coachMessage = "Five reps counted. Stay with it."
        coached.hapticsEnabled = false
        coached.languageCode = "fr"
        #expect(WatchState(message: coached.message()) == coached)
        let old = WatchState(message: ["type": "state", "v": 1, "stage": "capturing", "reps": 2])
        #expect(old?.setID == nil)
        #expect(old?.coachMessage == nil)
        #expect(old?.hapticsEnabled == true)
        #expect(old?.languageCode == "en-GB")
    }

    @Test func rhythmSkipsMissedBeatsAndStopsWhenPhoneIsStale() {
        var clock = WatchRhythmClock(interval: 3)
        clock.resume(now: 10)
        let early = clock.shouldTap(now: 12, lastPhoneStateAt: 10, reachable: true)
        let first = clock.shouldTap(now: 13, lastPhoneStateAt: 10, reachable: true)
        let late = clock.shouldTap(now: 23, lastPhoneStateAt: 22, reachable: true)
        let burst = clock.shouldTap(now: 23.1, lastPhoneStateAt: 22, reachable: true)
        let phase = clock.shouldTap(now: 25, lastPhoneStateAt: 24, reachable: true)
        let nextPhase = clock.shouldTap(now: 25.9, lastPhoneStateAt: 24, reachable: true)
        let stale = clock.shouldTap(now: 39, lastPhoneStateAt: 22, reachable: true)
        clock.resume(now: 50)
        let disconnected = clock.shouldTap(now: 53, lastPhoneStateAt: 52, reachable: false)
        #expect(!early && first && late && !burst && phase && !nextPhase && !stale && !disconnected)
    }

    @Test func permissionAndPhoneHapticsGateRhythm() {
        #expect(!WatchRhythmPolicy.canEnable(permissionGranted: false))
        #expect(WatchRhythmPolicy.canEnable(permissionGranted: true))
        #expect(!WatchRhythmPolicy.canTap(enabled: true, masterHapticsEnabled: false,
                                         workoutRunning: true, capturing: true))
        #expect(!WatchRhythmPolicy.canTap(enabled: true, masterHapticsEnabled: true,
                                         workoutRunning: false, capturing: true))
        #expect(WatchRhythmPolicy.canTap(enabled: true, masterHapticsEnabled: true,
                                        workoutRunning: true, capturing: true))
    }

    @Test func languageUsesOneOfTheFourSupportedVariants() {
        #expect(WatchLanguage.resolved("en") == "en-GB")
        #expect(WatchLanguage.resolved("en_US") == "en-US")
        #expect(WatchLanguage.resolved("fr-CA") == "fr")
        #expect(WatchLanguage.resolved("es-ES") == "es")
    }
}
