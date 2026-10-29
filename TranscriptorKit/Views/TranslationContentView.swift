import SwiftUI

/// Reusable view that displays translation content: source language badge + normal form + synonyms + translation text + examples,
/// with a button at the top right that copies all of it.
/// Used in TranslationView, ActionView, and HistoryDetailView.
public struct TranslationContentView: View {

    private let sourceLanguage: String?
    private let normalForm: String?
    private let synonyms: String?
    private let translatedText: String
    private let examples: [TranslationExample]

    public init(
        normalForm: String? = nil,
        synonyms: String? = nil,
        translatedText: String,
        sourceLanguage: String? = nil,
        examples: [TranslationExample] = []
    ) {
        self.sourceLanguage = sourceLanguage
        self.normalForm = normalForm
        self.synonyms = synonyms
        self.translatedText = translatedText
        self.examples = examples
    }

    /// Initialize from a persisted TranslationResult.
    public init(result: TranslationResult) {
        self.sourceLanguage = result.sourceLanguage
        self.normalForm = result.normalForm
        self.synonyms = result.synonyms
        self.translatedText = result.translatedText
        self.examples = result.examples
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sourceLanguage {
                LanguageBadge(sourceLanguage)
            }

            // The copy button sits at the top right, next to the first block of the result.
            HStack(alignment: .top, spacing: 12) {
                if let normalForm = normalForm.nonEmpty {
                    header(normalForm: normalForm)
                } else {
                    translationText
                }

                CopyTranslationButton(copyText)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }

            if normalForm.nonEmpty != nil {
                translationText
            }

            // Examples
            if !examples.isEmpty {
                Divider()
                ExamplesView(examples)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Normal (dictionary) form in source language + synonyms.
    private func header(normalForm: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(normalForm)
                .font(.title3)
                .fontWeight(.semibold)

            if let synonyms = synonyms.nonEmpty {
                Text(synonyms)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var translationText: some View {
        Text(translatedText)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The whole result as plain text, in the order it's shown: normal form, synonyms,
    /// translation and examples ("original — translation").
    var copyText: String {
        var blocks: [String] = []
        if let normalForm = normalForm.nonEmpty {
            blocks.append([normalForm, synonyms.nonEmpty].compactMap { $0 }.joined(separator: "\n"))
        }
        blocks.append(translatedText)
        if !examples.isEmpty {
            blocks.append(examples.map { "• \($0.original) — \($0.translation)" }.joined(separator: "\n"))
        }
        return blocks.joined(separator: "\n\n")
    }
}

private extension Optional where Wrapped == String {
    /// `nil` for a missing or empty string.
    var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
