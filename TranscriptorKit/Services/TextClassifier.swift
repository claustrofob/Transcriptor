import Foundation
import FoundationModels

public enum TextClassifier {

    /// Classifies input text into one of three translation types using on-device Foundation Models.
    /// Falls back to heuristic classification if the model is unavailable.
    public static func classify(_ text: String) async -> TranslationType {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return heuristicClassify(text)
        }

        do {
            let session = LanguageModelSession()
            let prompt = """
            Classify the following text into exactly one category:
            - "word": a single word, possibly with an article or preposition (e.g. "das Haus", "au revoir", "podekscytowany")
            - "expression": a fixed expression, idiom, or phrasal verb (e.g. "break the ice", "в конце концов", "coûte que coûte")
            - "freeText": a full sentence, paragraph, or arbitrary text

            Text: \(text)
            """
            let response = try await session.respond(to: prompt, generating: TranslationType.self)
            return response.content
        } catch {
            return heuristicClassify(text)
        }
    }

    /// Simple heuristic fallback when on-device model is unavailable.
    private static func heuristicClassify(_ text: String) -> TranslationType {
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
