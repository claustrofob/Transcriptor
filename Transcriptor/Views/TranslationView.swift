import SwiftUI
import SwiftData
import TranscriptorKit

struct TranslationView: View {
    @State private var sourceText = ""
    @State private var session = TranslationSession()
    @State private var showClipboardAlert = false
    @State private var clipboardText = ""
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
                        TranslationResultView(session: session)
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
            // A target language picked in the result applies to the input bar too.
            .onChange(of: session.targetLanguage) { _, newValue in
                if let newValue { targetLanguage = newValue }
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

    // MARK: - Actions

    /// Moves the input text to the top of the screen and starts translating it,
    /// cancelling any request still in flight.
    private func submit(scrollProxy proxy: ScrollViewProxy) {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        sourceText = ""
        isTextFieldFocused = false
        session.translate(text, modelContext: modelContext)

        withAnimation {
            proxy.scrollTo(TranslationResultView.topID, anchor: .top)
        }
    }

    // MARK: - Clipboard

    private func checkClipboard() {
        guard sourceText.isEmpty,
              !showHistory, !showSettings,
              UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              // The input is emptied on submit, so don't re-offer text that is already translated.
              text.trimmingCharacters(in: .whitespacesAndNewlines) != session.sourceText
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
