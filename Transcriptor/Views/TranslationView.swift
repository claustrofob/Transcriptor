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
    @State private var translationTask: Task<Void, Never>?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        translationResult
                    }
                    .padding()
                    .padding(.bottom, 80)
                    .frame(maxWidth: .infinity, minHeight: 1)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.always)
                .contentMargins(.bottom, 0, for: .scrollIndicators)

                inputBar(proxy: proxy)
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkClipboard()
                }
            }
            .alert("Translate from Clipboard?", isPresented: $showClipboardAlert) {
                Button("Translate") {
                    sourceText = clipboardText
                    startTranslation { await translate(scrollProxy: proxy) }
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

    private func inputBar(proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Enter text to translate...", text: $sourceText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isTextFieldFocused)

                if !sourceText.isEmpty {
                    Button {
                        cancelAndClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            Button {
                startTranslation { await translate(scrollProxy: proxy) }
            } label: {
                Group {
                    if isTranslating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .frame(width: 48, height: 48)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranslating)
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var translationResult: some View {
        if let error {
            ErrorLabel(error)
        } else if !translatedText.isEmpty {
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
                    startTranslation { await retranslate(with: lang) }
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
        }
    }

    // MARK: - Actions

    private func startTranslation(_ operation: @escaping @MainActor () async -> Void) {
        translationTask?.cancel()
        translationTask = Task { await operation() }
    }

    private func cancelAndClear() {
        translationTask?.cancel()
        translationTask = nil
        isTranslating = false
        clearAll()
    }

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
        isTextFieldFocused = false
        clearAll()
        sourceText = text

        do {
            let output = try await TranslationHelper.translateAndSave(
                text: text,
                modelContext: modelContext
            )
            guard !Task.isCancelled else { return }

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
            guard !Task.isCancelled else { return }
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
            guard !Task.isCancelled else { return }
            translatedText = output.translatedText
            sourceLanguage = output.sourceLanguage
            normalForm = output.normalForm
            synonyms = output.synonyms
            examples = output.examples
        } catch {
            guard !Task.isCancelled else { return }
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
