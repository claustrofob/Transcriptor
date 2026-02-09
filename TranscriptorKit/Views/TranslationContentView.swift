import SwiftUI

/// Reusable view that displays a translation result: markdown text, examples, source language badge, and copy button.
/// Used in TranslationView, ActionView, and HistoryDetailView.
public struct TranslationContentView: View {

    private let translatedText: String
    private let sourceLanguage: String?
    private let examples: [TranslationExample]
    private let showCopyButton: Bool

    @State private var copied = false

    public init(
        translatedText: String,
        sourceLanguage: String? = nil,
        examples: [TranslationExample] = [],
        showCopyButton: Bool = true
    ) {
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.examples = examples
        self.showCopyButton = showCopyButton
    }

    /// Initialize from a persisted TranslationResult.
    public init(result: TranslationResult, showCopyButton: Bool = true) {
        self.translatedText = result.translatedText
        self.sourceLanguage = result.sourceLanguage
        self.examples = result.examples
        self.showCopyButton = showCopyButton
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Source language badge
            if let sourceLanguage {
                Label(sourceLanguage, systemImage: "textformat")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())
            }

            // Translation text
            MarkdownText(translatedText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Examples
            if !examples.isEmpty {
                Divider()
                ExamplesView(examples)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Copy button
            if showCopyButton {
                Button {
                    UIPasteboard.general.string = translatedText
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(
                        copied ? "Copied!" : "Copy Translation",
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(copied ? .green : nil)
            }
        }
    }
}
