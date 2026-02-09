import SwiftUI

/// Reusable view that displays translation content: markdown text + examples.
/// Used in TranslationView, ActionView, and HistoryDetailView.
public struct TranslationContentView: View {

    private let translatedText: String
    private let examples: [TranslationExample]

    public init(
        translatedText: String,
        examples: [TranslationExample] = []
    ) {
        self.translatedText = translatedText
        self.examples = examples
    }

    /// Initialize from a persisted TranslationResult.
    public init(result: TranslationResult) {
        self.translatedText = result.translatedText
        self.examples = result.examples
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Translation text (Markdown)
            MarkdownText(translatedText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Examples
            if !examples.isEmpty {
                Divider()
                ExamplesView(examples)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
