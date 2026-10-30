import SwiftUI
import TranscriptorKit

struct SettingsView: View {
    @State private var settings = SettingsManager.shared.settings
    @State private var apiKeys: [TranslationSettings.Provider: String] = Dictionary(
        uniqueKeysWithValues: TranslationSettings.Provider.allCases.map {
            ($0, KeychainService.shared.loadAPIKey(for: $0) ?? "")
        }
    )
    @State private var showAPIKey = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                aboutSection
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .onChange(of: settings) { _, newValue in
                SettingsManager.shared.settings = newValue
            }
        }
    }

    // MARK: - Sections

    private var providerSection: some View {
        let provider = settings.provider
        return Section {
            Picker("Provider", selection: $settings.provider) {
                ForEach(TranslationSettings.Provider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            if provider.requiresAPIKey {
                LabeledContent("API Key") {
                    HStack {
                        Group {
                            if showAPIKey {
                                TextField(provider.apiKeyPlaceholder, text: apiKeyBinding(for: provider))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField(provider.apiKeyPlaceholder, text: apiKeyBinding(for: provider))
                                    .textInputAutocapitalization(.never)
                            }
                        }
                        .font(.system(.body, design: .monospaced))

                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            switch provider {
            case .google:
                Picker("Model", selection: $settings.geminiModel) {
                    ForEach(TranslationSettings.GeminiModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
            case .anthropic:
                Picker("Model", selection: $settings.claudeModel) {
                    ForEach(TranslationSettings.ClaudeModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
            case .apple:
                // Reads the observable system model, so the row updates once the model is ready.
                LabeledContent("Status") {
                    Text(OnDeviceTranslationService.unavailabilityReason ?? "Available")
                        .multilineTextAlignment(.trailing)
                }
                if let isSupported = OnDeviceTranslationService.supportsLanguage(code: settings.targetLanguage) {
                    LabeledContent(TranslationSettings.displayName(forCode: settings.targetLanguage), value: isSupported ? "Supported" : "Not officially supported")
                }
            }
        } header: {
            Text("Provider")
        } footer: {
            Text(LocalizedStringKey(footerText(for: provider)))
                .environment(\.openURL, OpenURLAction { url in
                    .systemAction(url, prefersInApp: true)
                })
        }
    }

    private func footerText(for provider: TranslationSettings.Provider) -> String {
        guard provider == .apple, OnDeviceTranslationService.unavailabilityReason != nil else {
            return provider.apiKeyHint
        }
        return provider.apiKeyHint + " Requires Apple Intelligence: a supported iPhone, Apple Intelligence turned on and a Siri language it supports. If Settings shows \"Apple Intelligence & Siri\", turn it on there; if it only shows \"Siri\", Apple Intelligence isn't offered in the current configuration (e.g. the Siri language isn't supported). iOS then downloads the model by itself; apps can't see its progress."
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
        }
    }

    // MARK: - API key

    /// Each provider keeps its own key; editing one never touches the other.
    private func apiKeyBinding(for provider: TranslationSettings.Provider) -> Binding<String> {
        Binding {
            apiKeys[provider] ?? ""
        } set: { newValue in
            apiKeys[provider] = newValue
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try? KeychainService.shared.deleteAPIKey(for: provider)
            } else {
                try? KeychainService.shared.saveAPIKey(trimmed, for: provider)
            }
        }
    }
}

#Preview {
    SettingsView()
}
