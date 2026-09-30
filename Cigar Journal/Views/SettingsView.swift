// SettingsView
// Where the Anthropic API key for "Look Up Cigar" is entered. The key is kept in
// this device's Keychain only.

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var hasSavedKey = KeychainStore.anthropicAPIKey != nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(hasSavedKey ? "Key saved. Paste a new one to replace it" : "sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if hasSavedKey {
                        Button("Remove Saved Key", role: .destructive) {
                            KeychainStore.delete(KeychainStore.anthropicAPIKeyAccount)
                            hasSavedKey = false
                        }
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Used by Look Up Cigar to search the web for a cigar's size, shape and strength. Each lookup costs a few cents on your Anthropic account. The key is stored only in this device's Keychain. [Get a key](https://console.anthropic.com/settings/keys)")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        KeychainStore.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: KeychainStore.anthropicAPIKeyAccount)
                        dismiss()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
