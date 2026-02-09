import SwiftUI

/// A view that renders Markdown text with support for block-level elements
/// (bullet lists, numbered lists, headers) as well as inline formatting (**bold**, *italic*).
public struct MarkdownText: View {

    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
    }

    // MARK: - Block model

    private enum Block {
        case paragraph(String)
        case bulletItem(String)
        case numberedItem(number: String, text: String)
    }

    // MARK: - Parser

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")

        var pendingParagraph: [String] = []

        func flushParagraph() {
            if !pendingParagraph.isEmpty {
                let joined = pendingParagraph.joined(separator: "\n")
                blocks.append(.paragraph(joined))
                pendingParagraph.removeAll()
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Bullet list: "* text" or "- text"
            if let match = trimmed.wholeMatch(of: /^[\*\-]\s+(.+)$/) {
                flushParagraph()
                blocks.append(.bulletItem(String(match.1)))
            }
            // Numbered list: "1. text", "2. text" etc.
            else if let match = trimmed.wholeMatch(of: /^(\d+)\.\s+(.+)$/) {
                flushParagraph()
                blocks.append(.numberedItem(number: String(match.1), text: String(match.2)))
            }
            // Empty line — flush paragraph
            else if trimmed.isEmpty {
                flushParagraph()
            }
            // Regular text
            else {
                pendingParagraph.append(line)
            }
        }

        flushParagraph()
        return blocks
    }

    // MARK: - Rendering

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            inlineMarkdown(text)

        case .bulletItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                inlineMarkdown(text)
            }
            .padding(.leading, 8)

        case .numberedItem(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(number).")
                    .monospacedDigit()
                inlineMarkdown(text)
            }
            .padding(.leading, 8)
        }
    }

    private func inlineMarkdown(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        } else {
            return Text(text)
        }
    }
}
