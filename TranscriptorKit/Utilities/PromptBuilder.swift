import Foundation

public enum PromptBuilder {

    public static func systemPrompt(for settings: TranslationSettings) -> String {
        var parts: [String] = []

        parts.append("You are a professional translator.")
        parts.append("Translate the following text into \(settings.targetLanguage).")
        parts.append("IMPORTANT: Respond with plain text only. Do NOT use Markdown, bold, headers, bullet points, or any formatting. Do NOT repeat the source text or label sections.")

        switch settings.detailLevel {
        case .concise:
            parts.append("Provide only the direct translation, nothing else.")
        case .standard:
            parts.append("Start with the translation, then on a new line add brief context notes if the text contains idioms, slang, or ambiguous phrases.")
        case .detailed:
            parts.append("Start with the translation, then on a new line add explanations of nuances, idioms, cultural context, and alternative translations where applicable.")
        }

        if settings.includeExamples {
            parts.append("After the translation, add 1-2 short usage examples on new lines.")
        }

        parts.append("If the source text is already in \(settings.targetLanguage), translate it into English instead.")

        return parts.joined(separator: " ")
    }
}
