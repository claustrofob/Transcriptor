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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TranslationInputBox(
                        text: $inputText,
                        isFocused: $isTextFieldFocused,
                        phase: session.phase,
                        onTranslate: submit,
                        onStop: session.stop,
                        onEdit: session.edit
                    )

                    TranslationResultView(session: session, onRepeat: repeatTranslation)
                }
                .padding()
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
    private func repeatTranslation(_ text: String) {
        session.beginEditing()
        inputText = text
        isTextFieldFocused = true
    }
}

#Preview {
    ActionView(sourceText: "Hello, World! This is a test.") {
        print("Done")
    }
}
