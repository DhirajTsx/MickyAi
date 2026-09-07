import SwiftUI
import ServiceManagement

/// Settings view for configuring AI providers, secure credentials, and system behaviors.
public struct SettingsView: View {
    @ObservedObject var state: AssistantState
    @State private var apiKeyInput: String = ""
    @State private var hasKeyInStore: Bool = false
    @State private var saveStatusMessage: String?
    @State private var isLaunchAtLoginEnabled: Bool = false

    @State private var keySource: KeySource = .none

    public init(state: AssistantState) {
        self.state = state
    }

    public var body: some View {
        TabView {
            // AI Configuration Tab
            Form {
                Section("AI Brain Provider") {
                    Picker("Provider", selection: Binding(
                        get: { state.selectedProvider },
                        set: { newProvider in
                            state.selectProvider(newProvider)
                            loadKeyStatus()
                        }
                    )) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Default Model: \(state.selectedProvider.defaultModel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if state.selectedProvider.requiresAPIKey {
                    Section("API Key Configuration") {
                        HStack {
                            SecureField("Enter API Key (\(state.selectedProvider.keyPlaceholder))", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)

                            Button("Save to Keychain") {
                                saveApiKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        HStack(spacing: 8) {
                            Circle()
                                .fill(keySource != .none ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)

                            Text(keyStatusDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if keySource == .keychain {
                                Button("Remove Key", role: .destructive) {
                                    deleteApiKey()
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                        }

                        if let saveStatusMessage {
                            Text(saveStatusMessage)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                } else {
                    Section("Endpoint") {
                        Text("Local Ollama connects to http://localhost:11434 by default. No API key required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .tabItem {
                Label("AI Provider", systemImage: "brain.head.profile")
            }

            // Permissions Tab
            PermissionsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            // General & Launch Tab
            Form {
                Section("System") {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { isLaunchAtLoginEnabled },
                        set: { newValue in
                            toggleLaunchAtLogin(enable: newValue)
                        }
                    ))
                    .help("Automatically launch Mackey AI in the menu bar when your Mac boots.")
                }

                Section("About Mackey AI") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (Phase 1 Foundation)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text("Native macOS • SwiftUI • Menu Bar")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 520, height: 400)
        .onAppear {
            loadKeyStatus()
            checkLaunchAtLoginStatus()
        }
    }

    private var keyStatusDescription: String {
        switch keySource {
        case .envFile:
            return "API Key loaded from local .env file"
        case .environmentVariable:
            return "API Key loaded from Xcode Environment Variable"
        case .keychain:
            return "API Key securely stored in macOS Keychain"
        case .none:
            return "No API key configured (Enter below or add to .env file)"
        }
    }

    private func loadKeyStatus() {
        keySource = SecretStore.shared.getKeySource(for: state.selectedProvider)
        hasKeyInStore = (keySource != .none)
        apiKeyInput = ""
        saveStatusMessage = nil
    }

    private func saveApiKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let success = SecretStore.shared.saveKey(trimmed, for: state.selectedProvider)
        if success {
            hasKeyInStore = true
            apiKeyInput = ""
            saveStatusMessage = "Key saved successfully to Keychain."
        } else {
            saveStatusMessage = "Failed to save key. Check Keychain permissions."
        }
    }

    private func deleteApiKey() {
        let success = SecretStore.shared.deleteKey(for: state.selectedProvider)
        if success {
            hasKeyInStore = false
            apiKeyInput = ""
            saveStatusMessage = "Key removed from Keychain."
        }
    }

    private func checkLaunchAtLoginStatus() {
        isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
    }

    private func toggleLaunchAtLogin(enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
        } catch {
            saveStatusMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }
}
