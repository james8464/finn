import Foundation
import Testing
@testable import Finn

@MainActor
struct ModelGenerationGateTests {
    @Test func failedRequestDoesNotBlockTheNextRequest() async {
        let gate = ModelGenerationGate<Int>()
        let failed = await gate.response(timeout: .seconds(1)) { throw Failure.unavailable }
        #expect(failed == nil)
        let recovered = await gate.response(timeout: .seconds(1)) { 42 }
        #expect(recovered == 42)
    }

    @Test(arguments: [Duration.zero, .milliseconds(-1)])
    func expiredDeadlineNeverStartsGeneration(timeout: Duration) async {
        let gate = ModelGenerationGate<Int>()
        var called = false
        let value = await gate.response(timeout: timeout) {
            called = true
            return 42
        }
        #expect(value == nil)
        #expect(!called)
    }

    @Test func cancelledRequestNeverStartsGeneration() async {
        let gate = ModelGenerationGate<Int>()
        var called = false
        let request = Task {
            await gate.response(timeout: .seconds(1)) {
                called = true
                return 42
            }
        }
        request.cancel()
        #expect(await request.value == nil)
        #expect(!called)
    }

    private enum Failure: Error {
        case unavailable
    }
}
