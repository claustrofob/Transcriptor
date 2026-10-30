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
            ScrollViewReader { proxy in
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
                    .id(Self.inputRowID)

                    TranslationResultView(session: session) { text in
                        repeatTranslation(text, proxy: proxy)
                    }
                }
                .listStyle(.plain)
            }
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
    private func repeatTranslation(_ text: String, proxy: ScrollViewProxy) {
        session.beginEditing()
        sourceText = text
        // Far down the list, the input's row is off screen and unloaded, so it can't take focus yet:
        // scroll up first, then focus once the row is back.
        withAnimation {
            proxy.scrollTo(Self.inputRowID, anchor: .top)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isTextFieldFocused = true
        }
    }

    private static let inputRowID = "input"
}

#Preview {
    TranslationView()
}
