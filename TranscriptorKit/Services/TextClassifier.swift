import Foundation

public enum TextClassifier {

    /// Classifies input text into one of three translation types by word count and punctuation.
    /// The on-device model used to do this but misclassified short inputs ("Cześć", "Nie możesz")
    /// as free text, which dropped the dictionary-style result, so the rules are deterministic now.
    public static func classify(_ text: String) -> TranslationType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        let wordCount = words.count

        if wordCount <= 2 {
            return .word
        }

        let hasSentencePunctuation = trimmed.contains(where: { ".!?;:".contains($0) })

        if wordCount <= 5 && !hasSentencePunctuation {
            return .expression
        }

        return .freeText
    }
}
