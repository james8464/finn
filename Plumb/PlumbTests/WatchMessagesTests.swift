import Foundation
import Testing
@testable import Plumb

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

    /// WatchConnectivity carries property lists only: the message must serialize, nil values left out.
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

    @Test func aSavedStateFromLongAgoIsStale() {
        #expect(!full.isStale(now: full.sentAt + 30))
        #expect(full.isStale(now: full.sentAt + WatchState.staleAfter + 1))
    }
}
