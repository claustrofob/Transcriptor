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
                    startTranslation { await translate(scrollProxy: proxy) }
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
                        cancelAndClear()
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
                    startTranslation { await translate(scrollProxy: proxy) }
                } label: {
                    Group {
                        if isTranslating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(isSendDisabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white))
                    .frame(width: 36, height: 36)
                    .background(isSendDisabled && !isTranslating ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.tint), in: .circle)
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

    private var isSendDisabled: Bool {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranslating
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
              !showHistory, !showSettings,
              UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
