import SwiftUI
import SwiftData
import TranscriptorKit

struct ActionView: View {
    let sourceText: String
    let onDone: () -> Void

    @State private var translatedText = ""
    @State private var isTranslating = true
    @State private var errorMessage: String?
    @State private var sourceLanguage: String?
    @State private var normalForm: String?
    @State private var synonyms: String?
    @State private var examples: [TranslationExample] = []

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Original text
                    GroupBox {
                        Text(sourceText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Original", systemImage: "text.quote")
                            .font(.caption)
                    }

                    // Translation
                    GroupBox {
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if isTranslating && translatedText.isEmpty {
                            HStack {
                                ProgressView()
                                Text("Translating...")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        } else {
                            TranslationContentView(
                                normalForm: normalForm,
                                synonyms: synonyms,
                                translatedText: translatedText,
                                sourceLanguage: sourceLanguage,
                                examples: examples
                            )
                        }
                    } label: {
                        Label("Translation", systemImage: "text.bubble")
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("Transcriptor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDone() }
                }

                ToolbarItem(placement: .primaryAction) {
                    CopyTranslationButton(translatedText)
                }
            }
            .task { await translate() }
        }
    }

    // MARK: - Translation

    private func translate() async {
        let settings = SettingsManager.shared.settings

        guard KeychainService.shared.loadAPIKey() != nil else {
            errorMessage = "API key not configured. Please open Transcriptor and set your Google AI API key in Settings."
            isTranslating = false
            return
        }

        do {
            let meta = try await GeminiService.shared.translateFull(
                text: sourceText,
                settings: settings
            )

            translatedText = meta.translatedText
            sourceLanguage = meta.sourceLanguage
            normalForm = meta.normalForm
            synonyms = meta.synonyms.isEmpty ? nil : meta.synonyms
            examples = meta.examples

            // Save to history
            let result = TranslationResult(
                sourceText: sourceText,
                translatedText: meta.translatedText,
                normalForm: meta.normalForm,
                synonyms: meta.synonyms.isEmpty ? nil : meta.synonyms,
                shortTranslation: meta.shortTranslation,
                sourceLanguage: meta.sourceLanguage,
                targetLanguage: settings.targetLanguage,
                model: settings.model.rawValue,
                examples: meta.examples
            )
            modelContext.insert(result)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isTranslating = false
    }
}

#Preview {
    ActionView(sourceText: "Hello, World! This is a test.") {
        print("Done")
    }
}
