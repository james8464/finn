import Foundation
import os

/// A deadline bounds the caller's wait, but cannot force a framework to stop working. Keep one
/// generation in flight until it actually ends, so repeated taps cannot build up stalled requests.
@MainActor
final class ModelGenerationGate<Value: Sendable> {
    private var activeGeneration: UUID?
    private let log = Logger(subsystem: "ai.mwm.build.challenge.team.08", category: "model-generation")

    func response(timeout: Duration,
                  using work: @escaping @MainActor () async throws -> Value) async -> Value? {
        guard !Task.isCancelled, activeGeneration == nil, timeout > .zero else { return nil }
        let generationID = UUID()
        activeGeneration = generationID

        let stream = AsyncStream<Value?>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let generation = Task { @MainActor [weak self] in
                defer {
                    if self?.activeGeneration == generationID {
                        self?.activeGeneration = nil
                    }
                }
                do {
                    try Task.checkCancellation()
                    let response = try await work()
                    try Task.checkCancellation()
                    continuation.yield(response)
                } catch {
                    // Prompts and workout facts stay out of logs. The caller supplies its fallback.
                    self?.log.notice("Model generation ended without a response; using local wording.")
                    continuation.yield(nil)
                }
                continuation.finish()
            }
            let timer = Task.detached {
                guard (try? await Task.sleep(for: timeout)) != nil else { return }
                continuation.yield(nil)
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                generation.cancel()
                timer.cancel()
            }
        }

        var iterator = stream.makeAsyncIterator()
        return await iterator.next() ?? nil
    }
}
