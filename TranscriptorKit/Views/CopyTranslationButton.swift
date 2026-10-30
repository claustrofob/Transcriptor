import SwiftUI

/// Icon-only copy button that turns into a green checkmark ("Copied!") for a moment.
/// Used at the top right of `TranslationContentView`.
public struct CopyTranslationButton: View {

    private let text: String

    @State private var copied = false

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Button {
            UIPasteboard.general.string = text
            withAnimation { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { copied = false }
            }
        } label: {
            Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                // SF Symbols' Magic Replace morphs the copy icon into the checkmark and back.
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        // Neutral like the surrounding text; green while showing "Copied!".
        .tint(copied ? .green : .secondary)
        .disabled(text.isEmpty)
    }
}
