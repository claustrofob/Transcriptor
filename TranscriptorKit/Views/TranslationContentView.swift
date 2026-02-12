import SwiftUI

/// Reusable view that displays translation content: normal form + synonyms + translation text + examples.
/// Used in TranslationView, ActionView, and HistoryDetailView.
public struct TranslationContentView: View {

    private let normalForm: String?
    private let synonyms: String?
    private let translatedText: String
    private let examples: [TranslationExample]

    public init(
        normalForm: String? = nil,
        synonyms: String? = nil,
        translatedText: String,
        examples: [TranslationExample] = []
    ) {
        self.normalForm = normalForm
        self.synonyms = synonyms
        self.translatedText = translatedText
        self.examples = examples
    }

    /// Initialize from a persisted TranslationResult.
    public init(result: TranslationResult) {
        self.normalForm = result.normalForm
        self.synonyms = result.synonyms
        self.translatedText = result.translatedText
        self.examples = result.examples
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Normal (dictionary) form in source language + synonyms
            if let normalForm, !normalForm.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(normalForm)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if let synonyms, !synonyms.isEmpty {
                        Text(synonyms)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(translatedText)
                .textSelection(.enabled)
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
