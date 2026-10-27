import SwiftUI
import SwiftData
import TranscriptorKit

struct TranslationView: View {
    @State private var sourceText = ""
    /// Text of the last submitted request, shown at the top of the screen.
    @State private var submittedText: String?
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
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var targetLanguage = SettingsManager.shared.settings.targetLanguage
    @State private var detailLevel = SettingsManager.shared.settings.detailLevel

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
                    .padding(.bottom, 130)
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
            .onChange(of: targetLanguage) { _, newValue in
                SettingsManager.shared.settings.targetLanguage = newValue
            }
            .onChange(of: detailLevel) { _, newValue in
                SettingsManager.shared.settings.detailLevel = newValue
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkClipboard()
                }
            }
            .alert("Translate from Clipboard?", isPresented: $showClipboardAlert) {
                Button("Translate") {
                    sourceText = clipboardText
                    submit(scrollProxy: proxy)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(clipboardText.prefix(200) + (clipboardText.count > 200 ? "..." : ""))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showHistory = true
                } label: {
                    Label("History", systemImage: "clock")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        }
    }

    // MARK: - Subviews

    private func inputBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Enter text to translate...", text: $sourceText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isTextFieldFocused)
                    .padding(.leading, 3)

                if !sourceText.isEmpty {
                    Button {
                        sourceText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            // Same width as the send button so their centers line up.
                            .frame(width: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.top, 8)

            HStack(spacing: 8) {
                targetLanguageMenu
                detailLevelMenu

                Spacer(minLength: 0)

                Button {
                    submit(scrollProxy: proxy)
                } label: {
                    Image(systemName: "arrow.up")
                        .fontWeight(.semibold)
                        .foregroundStyle(isSendDisabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white))
                        .frame(width: 36, height: 36)
                        .background(isSendDisabled ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.tint), in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(isSendDisabled)
                .accessibilityLabel("Translate")
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.horizontal)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    // Sending while a translation is in flight is allowed: it cancels the previous request.
    private var isSendDisabled: Bool {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var targetLanguageMenu: some View {
        Menu {
            Picker("Target Language", selection: $targetLanguage) {
                ForEach(TranslationSettings.supportedLanguages, id: \.self) { language in
                    Text(language).tag(language)
                }
            }
        } label: {
            OptionChip(title: targetLanguage, systemImage: "arrow.right")
        }
        .tint(.primary)
        .accessibilityLabel("Target Language: \(targetLanguage)")
    }

    private var detailLevelMenu: some View {
        Menu {
            Picker("Detail Level", selection: $detailLevel) {
                ForEach(TranslationSettings.DetailLevel.allCases, id: \.self) { level in
                    Label(level.displayName, systemImage: level.systemImage).tag(level)
                }
            }
        } label: {
            OptionChip(title: detailLevel.displayName, systemImage: detailLevel.systemImage)
        }
        .tint(.primary)
        .accessibilityLabel("Detail Level: \(detailLevel.displayName)")
    }

    @ViewBuilder
    private var translationResult: some View {
        if let submittedText {
            GroupBox {
                Text(submittedText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Original", systemImage: "text.quote")
                    .font(.caption)
            }
            .id("original")

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
                            retranslate(with: lang)
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
    }

    // MARK: - Actions

    /// Moves the input text to the top of the screen and starts translating it,
    /// cancelling any request still in flight (a cancelled request is not saved to history).
    private func submit(scrollProxy proxy: ScrollViewProxy) {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        sourceText = ""
        isTextFieldFocused = false
        submittedText = text
        selectedSourceLanguage = nil
        startTranslation(text: text, sourceLanguage: nil)

        withAnimation {
            proxy.scrollTo("original", anchor: .top)
        }
    }

    private func retranslate(with lang: TranslationSettings.SourceLanguage) {
        guard let submittedText else { return }
        startTranslation(text: submittedText, sourceLanguage: lang)
    }

    private func startTranslation(text: String, sourceLanguage lang: TranslationSettings.SourceLanguage?) {
        translationTask?.cancel()
        resetResult()
        isTranslating = true
        translationTask = Task { await translate(text: text, sourceLanguage: lang) }
    }

    private func resetResult() {
        translatedText = ""
        sourceLanguage = nil
        normalForm = nil
        synonyms = nil
        examples = []
        error = nil
    }

    /// Pass `lang` to override auto-detection; otherwise the detected language becomes the picker selection.
    private func translate(text: String, sourceLanguage lang: TranslationSettings.SourceLanguage?) async {
        do {
            let output = try await TranslationHelper.translateAndSave(
                text: text,
                modelContext: modelContext,
                sourceLanguage: lang?.name
            )
            guard !Task.isCancelled else { return }

            translatedText = output.translatedText
            sourceLanguage = output.sourceLanguage
            if lang == nil {
                selectedSourceLanguage = TranslationSettings.sourceLanguage(fromGeminiString: output.sourceLanguage)
                if let code = selectedSourceLanguage?.code {
                    LanguageFrequencyStore.shared.record(code: code)
                }
            }
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
              !showHistory, !showSettings,
              UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              // The input is emptied on submit, so don't re-offer text that is already translated.
              text.trimmingCharacters(in: .whitespacesAndNewlines) != submittedText
        else { return }

        clipboardText = text
        showClipboardAlert = true
    }
}

private extension TranslationSettings.DetailLevel {
    /// Mirrors the shape of the formatted result: plain text, bulleted examples, numbered meanings.
    var systemImage: String {
        switch self {
        case .concise: "text.alignleft"
        case .standard: "list.bullet"
        case .detailed: "list.number"
        }
    }
}

/// Compact icon + value label used for the option menus in the input bar.
private struct OptionChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.fill.tertiary, in: .capsule)
    }
}

#Preview {
    TranslationView()
}
