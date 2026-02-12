import SwiftUI

/// Reusable copy button with "Copied!" feedback animation.
/// Used in TranslationView, ActionView, and HistoryDetailView.
public struct CopyTranslationButton: View {

    private let text: String
    private let label: String
    private let fullWidth: Bool

    @State private var copied = false

    /// - Parameters:
    ///   - text: The text to copy to clipboard.
    ///   - label: Button label when not copied (default "Copy").
    ///   - fullWidth: Use full-width bordered style (default false, for toolbar use).
    public init(_ text: String, label: String = "Copy", fullWidth: Bool = false) {
        self.text = text
        self.label = label
        self.fullWidth = fullWidth
    }

    public var body: some View {
        if fullWidth {
            button
                .buttonStyle(.bordered)
                .tint(copied ? .green : nil)
        } else {
            button
        }
    }

    private var button: some View {
        Button {
            UIPasteboard.general.string = text
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        } label: {
            Label(
                copied ? "Copied!" : label,
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, fullWidth ? 12 : 0)
        }
        .disabled(text.isEmpty)
    }
}
