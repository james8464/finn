#if DEBUG
import SwiftUI

/// Options > Developer, Debug builds only: paste the demo API key once, choose the engine
/// the key goes to the Keychain of this iPhone and is never shown again
struct CoachDeveloperSection: View {
    @State private var pastedKey = ""
    @State private var hasKey = CoachDemoKeyStore.hasKey
    @State private var usesClaude = CoachDemoPreferences(defaults: .standard).usesClaude
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer").font(.headline).foregroundStyle(Color.primary).accessibilityAddTraits(.isHeader)
            Text("Debug build only. The App Store build has none of this: it uses Foundation Models and nothing else.")
                .foregroundStyle(HomeStyle.supportingText)
            Toggle("Coach demo through Claude Sonnet", isOn: Binding(
                get: { usesClaude },
                set: { isOn in
                    usesClaude = isOn
                    CoachDemoPreferences(defaults: .standard).usesClaude = isOn
                }
            ))
            .font(.body)
            .foregroundStyle(Color.primary)
            .tint(Color(uiColor: .systemGreen))
            .frame(minHeight: 44)
            .disabled(!hasKey)
            .accessibilityIdentifier("options.coachDemo")
            Text(hasKey
                 ? "A demo key is stored in this iPhone's Keychain. Off, the coach uses Foundation Models."
                 : "No demo key stored: the coach uses Foundation Models. Paste a key below to enable the demo.")
                .foregroundStyle(HomeStyle.supportingText)
            HStack(spacing: 10) {
                SecureField("Paste the demo API key", text: $pastedKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(HomeStyle.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("options.coachDemoKey")
                Button("Save") {
                    if CoachDemoKeyStore.save(pastedKey) {
                        hasKey = true
                        note = "Key saved in the Keychain."
                    } else {
                        note = "The key could not be saved."
                    }
                    pastedKey = ""
                }
                .disabled(pastedKey.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("options.coachDemoSave")
            }
            if hasKey {
                Button("Remove the stored key", role: .destructive) {
                    CoachDemoKeyStore.remove()
                    hasKey = false
                    note = "Key removed."
                }
                .accessibilityIdentifier("options.coachDemoRemove")
            }
            if let note {
                Text(note).foregroundStyle(HomeStyle.supportingText)
            }
        }
    }
}
#endif
