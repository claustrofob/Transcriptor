import SwiftUI
import SwiftData
import TranscriptorKit

struct ActionView: View {
    let sourceText: String
    let onDone: () -> Void

    @State private var session = TranslationSession()
    @State private var inputText: String
    @FocusState private var isTextFieldFocused: Bool

    @Environment(\.modelContext) private var modelContext

    init(sourceText: String, onDone: @escaping () -> Void) {
        self.sourceText = sourceText
        self.onDone = onDone
        self._inputText = State(initialValue: sourceText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TranslationInputBox(text: $inputText, isFocused: $isTextFieldFocused) {
                        submit()
                    }

                    TranslationResultView(session: session)
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

                ToolbarItem(placement: .primaryAction) {
                    CopyTranslationButton(session.translatedText)
                }
            }
            .task {
                session.translate(sourceText, modelContext: modelContext)
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
}

#Preview {
    ActionView(sourceText: "Hello, World! This is a test.") {
        print("Done")
    }
}
