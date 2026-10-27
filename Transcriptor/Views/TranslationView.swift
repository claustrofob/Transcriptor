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

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TranslationInputBox(text: $sourceText, isFocused: $isTextFieldFocused) {
                        submit()
                    }

                    TranslationResultView(session: session)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: 1)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.always)
            .dismissesKeyboardOnTap()
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkClipboard()
                }
            }
            .alert("Translate from Clipboard?", isPresented: $showClipboardAlert) {
                Button("Translate") {
                    sourceText = clipboardText
                    submit()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(clipboardText.prefix(200) + (clipboardText.count > 200 ? "..." : ""))
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

    // MARK: - Actions

    /// Translates the input text, cancelling any request still in flight. The text stays in the input.
    private func submit() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTextFieldFocused = false
        session.translate(text, modelContext: modelContext)
    }

    // MARK: - Clipboard

    private func checkClipboard() {
        let input = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !showHistory, !showSettings,
              // Don't interrupt a draft: only offer when the input is empty or holds the translated text.
              input.isEmpty || input == session.sourceText,
              UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              text != session.sourceText
        else { return }

        clipboardText = text
        showClipboardAlert = true
    }
}

#Preview {
    TranslationView()
}
