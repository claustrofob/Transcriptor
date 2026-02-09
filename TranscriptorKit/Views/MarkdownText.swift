import SwiftUI

/// A view that renders a string as Markdown with text selection support.
/// Falls back to plain text if Markdown parsing fails.
public struct MarkdownText: View {

    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .textSelection(.enabled)
        } else {
            Text(text)
                .textSelection(.enabled)
        }
    }
}
