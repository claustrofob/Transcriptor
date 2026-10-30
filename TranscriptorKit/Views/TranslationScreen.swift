import SwiftUI
import SwiftData

/// The Translate screen, shared by the app and the Share extension: the input, the language bar,
/// the result and the history as rows of one List (so history cards get the system swipe actions).
/// Put it in a NavigationStack, which history entries open in, and add the toolbar there.
public struct TranslationScreen: View {
    @State private var text: String
    @State private var session = TranslationSession()
    @FocusState private var isInputFocused: Bool

    @Environment(\.modelContext) private var modelContext

    /// `initialText` only fills the input; the user starts the translation with Translate.
    public init(initialText: String = "") {
        _text = State(initialValue: initialText)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            List {
                TranslationInputBox(
                    text: $text,
                    isFocused: $isInputFocused,
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
    }

    private static let inputRowID = "input"

    /// Translates the input text, cancelling any request still in flight. The text stays in the input.
    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isInputFocused = false
        session.translate(trimmed, modelContext: modelContext)
    }

    /// Puts a history entry's text into the input and focuses it; the user sends it with Translate.
    private func repeatTranslation(_ entryText: String, proxy: ScrollViewProxy) {
        session.beginEditing()
        text = entryText
        // Far down the list, the input's row is off screen and unloaded, so it can't take focus yet:
        // scroll up first, then focus once the row is back.
        withAnimation {
            proxy.scrollTo(Self.inputRowID, anchor: .top)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isInputFocused = true
        }
    }
}
