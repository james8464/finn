import Foundation
import Testing
@testable import Plumb

nonisolated struct AccessoriesTests {
    @Test func noExerciseNeedsAnAccessoryAndBothHelpEveryExercise() {
        for exercise in ExerciseKind.allCases {
            let roles = AccessoryRoles.roles(for: exercise)
            #expect(roles.map(\.accessory) == [.appleWatch, .headphones])
            for role in roles {
                #expect(!role.isRequired)
                #expect(role.isUsed)
                #expect(role.exercise == exercise)
            }
        }
    }

    @Test func headphonesSayTheCountdownRepsAndObservationsForEveryExercise() {
        for exercise in ExerciseKind.allCases {
            let role = AccessoryRoles.role(of: .headphones, for: exercise)
            #expect(role.features == [.hearCountdownRepsAndObservations])
            #expect(role.limitation == nil)
        }
    }

    @Test func theWatchCoachesAndOffersRhythmForEveryExercise() {
        for exercise in ExerciseKind.allCases {
            let role = AccessoryRoles.role(of: .appleWatch, for: exercise)
            #expect(role.features == [.seeCoachMessages, .feelRhythmTaps])
            #expect(role.limitation == nil)
            #expect(!role.offers(.startStopFromWrist))
        }
    }

    @Test func noLineWhenNothingIsAround() {
        for exercise in ExerciseKind.allCases {
            #expect(AccessoryGuide.setupLines(for: exercise, status: .none, speaksLive: true).isEmpty)
        }
        #expect(!AccessoryStatus.none.isConnected(.appleWatch))
        #expect(!AccessoryStatus.none.isConnected(.headphones))
    }

    @Test func headphonesLineDependsOnSpeech() {
        let status = AccessoryStatus(headphonesConnected: true)
        #expect(status.isConnected(.headphones))
        #expect(AccessoryGuide.setupLines(for: .bodyweightSquat, status: status, speaksLive: true)
                == [AccessoryLine(accessory: .headphones, text: "Headphones connected: you will hear each rep.")])
        #expect(AccessoryGuide.setupLines(for: .bodyweightSquat, status: status, speaksLive: false).map(\.text)
                == ["Headphones connected. Turn on Say reps aloud in Options to hear each rep."])
    }

    @Test func watchLineFollowsPairingInstallAndReachability() {
        func text(_ watch: WatchConnection, _ exercise: ExerciseKind = .bodyweightSquat) -> String? {
            AccessoryGuide.watchLine(for: exercise, status: AccessoryStatus(watch: watch))?.text
        }
        #expect(text(WatchConnection(isPaired: false, isAppInstalled: true, isReachable: true)) == nil)
        #expect(text(WatchConnection(isPaired: true)) ==
                "Apple Watch: install Plumb for coaching messages and optional rhythm taps.")
        #expect(text(WatchConnection(isPaired: true, isAppInstalled: true)) ==
                "Apple Watch: open Plumb on your watch for coaching messages and rhythm.")
        #expect(text(WatchConnection(isPaired: true, isAppInstalled: true, isReachable: true)) ==
                "Apple Watch connected: coaching messages are ready; rhythm is optional.")
        #expect(text(WatchConnection(isPaired: true, isAppInstalled: true), .pushUp) ==
                "Apple Watch: open Plumb on your watch for coaching messages and rhythm.")
        #expect(text(WatchConnection(isPaired: true, isAppInstalled: true, isReachable: true), .pushUp) ==
                "Apple Watch connected: coaching messages are ready; rhythm is optional.")
        #expect(AccessoryStatus(watch: WatchConnection(isPaired: true, isAppInstalled: true, isReachable: true))
            .isConnected(.appleWatch))
        #expect(!AccessoryStatus(watch: WatchConnection(isPaired: true, isAppInstalled: true))
            .isConnected(.appleWatch))
    }

    @Test func bothAccessoriesGiveOneLineEachHeadphonesFirst() {
        let status = AccessoryStatus(headphonesConnected: true,
                                     watch: WatchConnection(isPaired: true, isAppInstalled: true, isReachable: true))
        let lines = AccessoryGuide.setupLines(for: .staticLunge, status: status, speaksLive: true)
        #expect(lines.map(\.accessory) == [.headphones, .appleWatch])
    }

    /// The lines promise delivery only: Plumb's measurements come from the iPhone camera.
    @Test func noLineClaimsTheAccessoryMeasures() {
        let statuses = [
            AccessoryStatus(headphonesConnected: true),
            AccessoryStatus(watch: WatchConnection(isPaired: true)),
            AccessoryStatus(watch: WatchConnection(isPaired: true, isAppInstalled: true)),
            AccessoryStatus(headphonesConnected: true,
                            watch: WatchConnection(isPaired: true, isAppInstalled: true, isReachable: true)),
        ]
        for exercise in ExerciseKind.allCases {
            for status in statuses {
                for speaks in [true, false] {
                    for line in AccessoryGuide.setupLines(for: exercise, status: status, speaksLive: speaks) {
                        let text = line.text.lowercased()
                        for word in ["measure", "track", "detect", "sensor", "heart", "injur"] {
                            #expect(!text.contains(word), "\(line.text)")
                        }
                    }
                }
            }
        }
    }
}
