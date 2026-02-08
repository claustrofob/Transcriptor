import SwiftUI
import TranscriptorKit

struct SettingsView: View {
    @State private var settings = SettingsManager.shared.settings
    @State private var apiKey = KeychainService.shared.loadAPIKey() ?? ""
    @State private var showAPIKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if showAPIKey {
                                TextField("AIza...", text: $apiKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("AIza...", text: $apiKey)
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
                } header: {
                    Text("Google AI API Key")
                } footer: {
                    Text("Get your free API key at aistudio.google.com. Stored securely in Keychain.")
                }

                Section("Translation") {
                    Picker("Target Language", selection: $settings.targetLanguage) {
                        ForEach(TranslationSettings.supportedLanguages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }

                    Picker("Model", selection: $settings.model) {
                        ForEach(TranslationSettings.GeminiModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }

                    Picker("Detail Level", selection: $settings.detailLevel) {
                        ForEach(TranslationSettings.DetailLevel.allCases, id: \.self) { level in
                            VStack(alignment: .leading) {
                                Text(level.displayName)
                            }
                            .tag(level)
                        }
                    }

                    Toggle("Include Examples", isOn: $settings.includeExamples)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: apiKey) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    try? KeychainService.shared.deleteAPIKey()
                } else {
                    try? KeychainService.shared.saveAPIKey(trimmed)
                }
            }
            .onChange(of: settings) { _, newValue in
                SettingsManager.shared.settings = newValue
            }
        }
    }
}

#Preview {
    SettingsView()
}
