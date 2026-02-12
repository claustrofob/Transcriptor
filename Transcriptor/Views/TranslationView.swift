import SwiftUI
import SwiftData
import TranscriptorKit

struct TranslationView: View {
    @State private var sourceText = ""
    @State private var translatedText = ""
    @State private var isTranslating = false
    @State private var error: String?
    @State private var showClipboardAlert = false
    @State private var clipboardText = ""
    @State private var sourceLanguage: String?
    @State private var normalForm: String?
    @State private var synonyms: String?
    @State private var examples: [TranslationExample] = []

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Source text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Enter text to translate...", text: $sourceText, axis: .vertical)
                            .lineLimit(1...)
                            .padding(12)
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .focused($isTextFieldFocused)
                    }

                    // Translate button
                    Button {
                        isTextFieldFocused = false
                        Task { await translate(scrollProxy: proxy) }
                    } label: {
                        HStack {
                            if isTranslating {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isTranslating ? "Translating..." : "Translate")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranslating)

                    // Translation result
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    } else if !translatedText.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Translation")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TranslationContentView(
                                normalForm: normalForm,
                                synonyms: synonyms,
                                translatedText: translatedText,
                                sourceLanguage: sourceLanguage,
                                examples: examples
                            )
                        }
                        .id("translation")

                        CopyTranslationButton(translatedText, label: "Copy Translation", fullWidth: true)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isTextFieldFocused = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sourceText = ""
                        translatedText = ""
                        sourceLanguage = nil
                        normalForm = nil
                        synonyms = nil
                        examples = []
                        error = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(sourceText.isEmpty && translatedText.isEmpty)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkClipboard()
                }
            }
            .alert("Translate from Clipboard?", isPresented: $showClipboardAlert) {
                Button("Translate") {
                    sourceText = clipboardText
                    Task { await translate(scrollProxy: proxy) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(clipboardText.prefix(200) + (clipboardText.count > 200 ? "..." : ""))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Translation

    private func translate(scrollProxy proxy: ScrollViewProxy) async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTranslating = true
        translatedText = ""
        sourceLanguage = nil
        normalForm = nil
        synonyms = nil
        examples = []
        error = nil

        let settings = SettingsManager.shared.settings

        do {
            let meta = try await GeminiService.shared.translateFull(
                text: text,
                settings: settings
            )

            translatedText = meta.translatedText
            sourceLanguage = meta.sourceLanguage
            normalForm = meta.normalForm
            synonyms = meta.synonyms.isEmpty ? nil : meta.synonyms
            examples = meta.examples

            withAnimation {
                proxy.scrollTo("translation", anchor: .top)
            }

            // Save to history
            let result = TranslationResult(
                sourceText: text,
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
            self.error = error.localizedDescription
        }

        isTranslating = false
    }

    // MARK: - Clipboard

    private func checkClipboard() {
        guard sourceText.isEmpty,
              UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        clipboardText = text
        showClipboardAlert = true
    }
}

#Preview {
    TranslationView()
}
