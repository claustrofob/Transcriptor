import SwiftUI
import SwiftData
import TranscriptorKit

struct TranslationView: View {
    @State private var sourceText = ""
    @State private var session = TranslationSession()
    @State private var showSettings = false

    @Environment(\.modelContext) private var modelContext
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            // A List, so history cards get the system swipe actions.
            List {
                TranslationInputBox(
                    text: $sourceText,
                    isFocused: $isTextFieldFocused,
                    phase: session.phase,
                    onTranslate: submit,
                    onStop: session.stop,
                    onEdit: session.edit
                )
                .cardRow()

                TranslationResultView(session: session, onRepeat: repeatTranslation)
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.always)
            .dismissesKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
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

    /// Puts a history entry's text into the input and focuses it; the user sends it with Translate.
    private func repeatTranslation(_ text: String) {
        session.beginEditing()
        sourceText = text
        isTextFieldFocused = true
    }
}

#Preview {
    TranslationView()
}
