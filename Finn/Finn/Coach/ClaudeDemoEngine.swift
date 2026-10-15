#if DEBUG
import Foundation
import Security

// Debug builds only. Nothing in this file exists in the App Store build: no key, no endpoint.

/// the demo API key, kept in this iPhone's Keychain and nowhere else. The person pastes it once in
/// Options > Developer
nonisolated enum CoachDemoKeyStore {
    private static let service = "ai.mwm.build.challenge.team.08.coach-demo"
    private static let account = "anthropic"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> String? {
        var item = query
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func remove() {
        SecItemDelete(query as CFDictionary)
    }

    static var hasKey: Bool { load() != nil }
}

/// debug-only options for the coach demo
nonisolated struct CoachDemoPreferences {
    static let usesClaudeKey = "finn.coach.usesClaudeDemo"
    let defaults: UserDefaults

    /// on by default: with a key in the Keychain, the demo answers through Claude Sonnet, and the
    /// switch in Options > Developer goes back to Foundation Models
    var usesClaude: Bool {
        get { defaults.object(forKey: Self.usesClaudeKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.usesClaudeKey) }
    }
}

/// Claude Sonnet through the Anthropic Messages API, with the same instructions and context as
/// the Foundation Models engines. Available only when a key is stored and the switch is on.
@MainActor
final class ClaudeDemoCoachEngine: CoachEngine {
    let kind: CoachEngineKind = .claudeDemo
    static let model = "claude-sonnet-5-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let preferences: CoachDemoPreferences
    private let session: URLSession

    init(preferences: CoachDemoPreferences = CoachDemoPreferences(defaults: .standard),
         session: URLSession = .shared) {
        self.preferences = preferences
        self.session = session
    }

    var available: Bool { preferences.usesClaude && CoachDemoKeyStore.hasKey }

    struct RequestError: Error, LocalizedError {
        let status: Int
        var errorDescription: String? { "Anthropic API answered \(status)." }
    }

    func reply(to question: String, context: CoachContext, history: [CoachMessage],
               language: CoachLanguage) async throws -> String {
        guard let key = CoachDemoKeyStore.load() else { throw RequestError(status: 401) }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.body(question: question, context: context,
                                                                                history: history, language: language))
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw RequestError(status: status) }
        return try Self.text(from: data)
    }

    static func body(question: String, context: CoachContext, history: [CoachMessage],
                     language: CoachLanguage) -> [String: Any] {
        var messages: [[String: String]] = history.suffix(10).map { message in
            ["role": message.role == .person ? "user" : "assistant", "content": message.text]
        }
        // the API wants alternating roles starting with the person; the coach's opening line is dropped
        if messages.first?["role"] == "assistant" { messages.removeFirst() }
        messages.append(["role": "user", "content": FoundationModelsCoachPrompt.prompt(
            question: question, context: context, history: [])])
        return ["model": model,
                "max_tokens": 300,
                "system": FoundationModelsCoachPrompt.instructions(language: language),
                "messages": messages]
    }

    static func text(from data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let blocks = json?["content"] as? [[String: Any]] ?? []
        let text = blocks.compactMap { block -> String? in
            block["type"] as? String == "text" ? block["text"] as? String : nil
        }.joined(separator: "\n")
        guard !text.isEmpty else { throw RequestError(status: 0) }
        return text
    }
}
#endif
