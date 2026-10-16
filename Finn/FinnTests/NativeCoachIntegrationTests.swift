import FoundationModels
import XCTest
@testable import Finn

/// Opt-in because ordinary CI machines need not have Apple's model assets installed.
/// An enabled run must use the real engine; a fallback answer fails the assertion.
final class NativeCoachIntegrationTests: XCTestCase {
    @MainActor
    func testNativeModelSelectsRecordedFactsAcrossSupportedLanguages() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FINN_NATIVE_COACH_TESTS"] == "1",
                          "Set TEST_RUNNER_FINN_NATIVE_COACH_TESTS=1 to test real Apple Intelligence.")
        let engine = OnDeviceCoachEngine()
        try XCTSkipUnless(engine.available, engine.unavailableReason ?? "Apple Intelligence unavailable")
        let context = CoachContext(facts: [
            CoachSetFact(number: 1, id: UUID(), exerciseName: "Squat", repCount: 6,
                         capturedAt: .now, observation: nil, issues: [], comparison: nil,
                         partlyVisible: false),
            CoachSetFact(number: 2, id: UUID(), exerciseName: "Push-up", repCount: 8,
                         capturedAt: .now, observation: nil, issues: [], comparison: nil,
                         partlyVisible: false)
        ])
        let questions: [(String, CoachLanguage, String)] = [
            ("en-GB", .english, "How many repetitions did I do in squat set 1?"),
            ("en-US", .english, "How many reps did I do in squat set 1?"),
            ("fr", .french, "Combien de répétitions dans ma série de squats, la série 1 ?"),
            ("es", .spanish, "¿Cuántas repeticiones hice en mi serie 1 de sentadillas?")
        ]
        for (locale, language, question) in questions {
            XCTAssertTrue(SystemLanguageModel.default.supportsLocale(Locale(identifier: locale)))
            let responder = CoachResponder(selector: CoachEngineSelector(engines: [engine]),
                                           timeout: .seconds(30), language: language)
            responder.prepare()
            let answer = await responder.answer(question, context: context, history: [])
            XCTAssertEqual(answer.engine, .onDevice, "\(locale): a fallback is not a model pass")
            XCTAssertEqual(answer.text, CoachFallback.summary(of: context.facts[0], language: language))
        }
    }
}
