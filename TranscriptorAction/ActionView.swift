import SwiftUI
import SwiftData
import TranscriptorKit

struct ActionView: View {
    let sourceText: String
    let onDone: () -> Void

    @State private var translatedText = ""
    @State private var isTranslating = true
    @State private var error: String?
    @State private var sourceLanguage: String?
    @State private var selectedSourceLanguage: TranslationSettings.SourceLanguage?
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
                        if let error {
                            ErrorLabel(error)
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
                            VStack(alignment: .leading, spacing: 12) {
                                SourceLanguagePicker(
                                    selected: selectedSourceLanguage,
                                    fallbackLabel: sourceLanguage,
                                    isDisabled: isTranslating
                                ) { lang in
                                    LanguageFrequencyStore.shared.record(code: lang.code)
                                    selectedSourceLanguage = lang
                                    Task { await retranslate(with: lang) }
                                }

                                TranslationContentView(
                                    normalForm: normalForm,
                                    synonyms: synonyms,
                                    translatedText: translatedText,
                                    sourceLanguage: nil,
                                    examples: examples
                                )
                            }
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
        do {
            let output = try await TranslationHelper.translateAndSave(
                text: sourceText,
                modelContext: modelContext
            )

            translatedText = output.translatedText
            sourceLanguage = output.sourceLanguage
            selectedSourceLanguage = TranslationSettings.sourceLanguage(fromGeminiString: output.sourceLanguage)
            if let code = selectedSourceLanguage?.code {
                LanguageFrequencyStore.shared.record(code: code)
            }
            normalForm = output.normalForm
            synonyms = output.synonyms
            examples = output.examples
        } catch {
            self.error = error.localizedDescription
        }

        isTranslating = false
    }

    private func retranslate(with lang: TranslationSettings.SourceLanguage) async {
        isTranslating = true
        translatedText = ""
        normalForm = nil
        synonyms = nil
        examples = []
        error = nil

        do {
            let output = try await TranslationHelper.translateAndSave(
                text: sourceText,
                modelContext: modelContext,
                sourceLanguage: lang.name
            )
            translatedText = output.translatedText
            sourceLanguage = output.sourceLanguage
            normalForm = output.normalForm
            synonyms = output.synonyms
            examples = output.examples
        } catch {
            self.error = error.localizedDescription
        }

        isTranslating = false
    }
}

#Preview {
    ActionView(sourceText: "Hello, World! This is a test.") {
        print("Done")
    }
}
