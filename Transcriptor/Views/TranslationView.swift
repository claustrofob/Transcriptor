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
    @State private var selectedSourceLanguage: TranslationSettings.SourceLanguage?
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
                    sourceTextField
                    translateButton(proxy: proxy)
                    translationResult
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
                        clearAll()
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

    // MARK: - Subviews

    private var sourceTextField: some View {
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
    }

    private func translateButton(proxy: ScrollViewProxy) -> some View {
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
    }

    @ViewBuilder
    private var translationResult: some View {
        if let error {
            ErrorLabel(error)
        } else if !translatedText.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Translation")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
            .id("translation")

            CopyTranslationButton(translatedText, label: "Copy Translation", fullWidth: true)
        }
    }

    // MARK: - Actions

    private func clearAll() {
        sourceText = ""
        translatedText = ""
        sourceLanguage = nil
        selectedSourceLanguage = nil
        normalForm = nil
        synonyms = nil
        examples = []
        error = nil
    }

    private func translate(scrollProxy proxy: ScrollViewProxy) async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTranslating = true
        clearAll()
        sourceText = text

        do {
            let output = try await TranslationHelper.translateAndSave(
                text: text,
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

            withAnimation {
                proxy.scrollTo("translation", anchor: .top)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isTranslating = false
    }

    private func retranslate(with lang: TranslationSettings.SourceLanguage) async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTranslating = true
        translatedText = ""
        normalForm = nil
        synonyms = nil
        examples = []
        error = nil

        do {
            let output = try await TranslationHelper.translateAndSave(
                text: text,
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
