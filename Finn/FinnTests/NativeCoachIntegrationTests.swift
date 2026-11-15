import FoundationModels
import XCTest
@testable import Finn

/// Opt-in because ordinary CI machines need not have Apple's model assets installed.
/// An enabled run must use the real engine; a fallback answer fails the assertion.
final class NativeCoachIntegrationTests: XCTestCase {
    @MainActor
    func testNativeModelChatsAcrossSupportedLanguages() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FINN_NATIVE_COACH_TESTS"] == "1",
            "Set TEST_RUNNER_FINN_NATIVE_COACH_TESTS=1 to test real Apple Intelligence."
        )
        let engine = OnDeviceCoachEngine()
        try XCTSkipUnless(engine.available, engine.unavailableReason ?? "Apple Intelligence unavailable")
        let context = CoachContext(facts: [
            CoachSetFact(
                number: 1,
                id: UUID(),
                exerciseName: "Squat",
                repCount: 6,
                capturedAt: .now,
                observation: nil,
                issues: [],
                comparison: nil,
                partlyVisible: false
            ),
            CoachSetFact(
                number: 2,
                id: UUID(),
                exerciseName: "Push-up",
                repCount: 8,
                capturedAt: .now,
                observation: nil,
                issues: [],
                comparison: nil,
                partlyVisible: false
            )
        ])
        let questions: [(String, CoachLanguage, String)] = [
            ("en", .english, "Hey coach, can we talk?"),
            ("en", .english, "How many reps did I do in squat set 1?"),
            ("fr", .french, "Hey, salut coach, on peut parler ?")
        ]
        for (locale, language, question) in questions {
            XCTAssertTrue(SystemLanguageModel.default.supportsLocale(Locale(identifier: locale)))
            let responder = CoachResponder(
                selector: CoachEngineSelector(engines: [engine]),
                timeout: .seconds(30),
                language: language
            )
            responder.prepare()
            let answer = await responder.answer(question, context: context, history: [])
            XCTAssertEqual(answer.engine, .onDevice, "\(locale): a fallback is not a model pass")
            XCTAssertFalse(answer.text.isEmpty, "\(locale): the model wrote nothing")
        }
    }

    /// replays the conversation that went round in circles: a greeting, then short answers. Each
    /// reply must move on: no second greeting, no first name, no sentence written twice. It also
    /// asks about the last set, which should use the latest saved record directly.
    @MainActor
    func testNativeModelKeepsAConversationGoing() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FINN_NATIVE_COACH_TESTS"] == "1",
            "Set TEST_RUNNER_FINN_NATIVE_COACH_TESTS=1 to test real Apple Intelligence."
        )
        let engine = OnDeviceCoachEngine()
        try XCTSkipUnless(engine.available, engine.unavailableReason ?? "Apple Intelligence unavailable")
        let profile = OnboardingProfile(
            goal: .comeback, level: .returning, favouriteExercises: [.bodyweightSquat, .pushUp], firstName: "Theo",
            intensity: .challenge, days: .threeToFour, location: .home, equipment: [.dumbbells, .pullUpBar],
            noPastInjuries: true
        )
        let sets = [(7, 11), (8, 13)].map { number, reps in
            CoachSetFact(number: number, id: UUID(), exerciseName: "Squat", repCount: reps, capturedAt: .now,
                         observation: nil, issues: [], comparison: nil, partlyVisible: false)
        }
        let script: [(CoachLanguage, [String], String)] = [
            (.english, ["Hey bro I can talk to you now", "Good", "ok", "How did my last set go?"], "Set 7"),
            (.french, ["Hey, salut coach, on peut parler ?", "Ça va bien", "ok", "Comment s'est passée ma dernière série ?"], "Série 7"),
        ]
        for (language, messages, earlierSet) in script {
            let responder = CoachResponder(
                selector: CoachEngineSelector(engines: [engine]),
                timeout: .seconds(30),
                language: language
            )
            let conversation = CoachConversation(
                history: [], responder: responder, profile: profile.coachMemory
            )
            // the replay uses these sets, as the screen would after recording them
            let context = CoachContext(facts: sets, profile: profile.coachMemory)
            var history = conversation.messages
            var sentences: Set<String> = []
            for (index, message) in messages.enumerated() {
                let answer = await responder.answer(message, context: context, history: history)
                print("> \(message)\nFinn: \(answer.text)\n")
                let isRecap = index == messages.count - 1
                XCTAssertEqual(answer.engine, isRecap ? .fallback : .onDevice)
                if index > 0 {
                    let opening = answer.text.lowercased()
                    for greeting in ["hey", "hi ", "hello", "salut", "theo"] {
                        XCTAssertFalse(opening.hasPrefix(greeting), "greeted again: \(answer.text)")
                    }
                }
                for sentence in answer.text.split(whereSeparator: { ".!?".contains($0) }) {
                    let normalised = sentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard normalised.count > 20 else {
                        continue
                    }
                    XCTAssertTrue(sentences.insert(normalised).inserted, "repeated: \(normalised)")
                }
                if !isRecap {
                    let reply = answer.text.lowercased().replacingOccurrences(of: "’", with: "'")
                    for phrase in ["sets of", "séries de", "va-t'en"] {
                        XCTAssertFalse(reply.contains(phrase), "Unsolicited workout or dismissive reply: \(answer.text)")
                    }
                }
                if isRecap {
                    XCTAssertEqual(answer.text, CoachFallback.summary(of: sets[1], language: language))
                    XCTAssertFalse(answer.text.contains(earlierSet))
                }
                history += [CoachMessage(role: .person, text: message), answer]
            }
        }
    }
}
