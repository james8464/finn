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

    @Test func theWatchShowsRepsAndTapsAndStartsSetsExceptWithHandsOnTheFloor() {
        for exercise in ExerciseKind.allCases where exercise != .pushUp {
            let role = AccessoryRoles.role(of: .appleWatch, for: exercise)
            #expect(role.features == [.seeRepCount, .feelRepTaps, .startStopFromWrist])
            #expect(role.limitation == nil)
        }
        let pushUp = AccessoryRoles.role(of: .appleWatch, for: .pushUp)
        #expect(pushUp.features == [.seeRepCount, .feelRepTaps])
        #expect(!pushUp.offers(.startStopFromWrist))
        #expect(pushUp.limitation != nil)
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
                "Apple Watch: install Plumb on your watch to see reps on your wrist.")
        #expect(text(WatchConnection(isPaired: true, isAppInstalled: true)) ==
                "Apple Watch: open Plumb on your watch to see reps and start sets from your wrist.")
        #expect(text(WatchConnection(isPaired: true, isAppInstalled: true, isReachable: true)) ==
                "Apple Watch connected: see each rep and start sets from your wrist.")
        // push-ups: the hands are on the floor, so the line never promises a wrist start
        #expect(text(WatchConnection(isPaired: true, isAppInstalled: true), .pushUp) ==
                "Apple Watch: open Plumb on your watch to see reps and feel a tap on each one.")
        #expect(text(WatchConnection(isPaired: true, isAppInstalled: true, isReachable: true), .pushUp) ==
                "Apple Watch connected: see each rep and feel a tap on your wrist.")
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

    /// the lines promise delivery only: Plumb's measurements come from the iPhone camera
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
