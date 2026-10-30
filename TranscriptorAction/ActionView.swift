import SwiftUI
import SwiftData
import TranscriptorKit

struct ActionView: View {
    let onDone: () -> Void

    @State private var session = TranslationSession()
    @State private var inputText: String
    @FocusState private var isTextFieldFocused: Bool

    @Environment(\.modelContext) private var modelContext

    /// The shared text only fills the input; the user starts the translation with Translate.
    init(sourceText: String, onDone: @escaping () -> Void) {
        self.onDone = onDone
        self._inputText = State(initialValue: sourceText)
    }

    var body: some View {
        NavigationStack {
            // A List, so history cards get the system swipe actions.
            ScrollViewReader { proxy in
                List {
                    TranslationInputBox(
                        text: $inputText,
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
            .dismissesKeyboardOnTap()
            .navigationTitle("Transcriptor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDone() }
                }
            }
        }
    }

    /// Re-translates the edited input, cancelling any request still in flight.
    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTextFieldFocused = false
        session.translate(text, modelContext: modelContext)
    }

    /// Puts a history entry's text into the input and focuses it; the user sends it with Translate.
    private func repeatTranslation(_ text: String, proxy: ScrollViewProxy) {
        session.beginEditing()
        inputText = text
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
    ActionView(sourceText: "Hello, World! This is a test.") {
        print("Done")
    }
}
