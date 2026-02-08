import Foundation

public enum PromptBuilder {

    /// Full translation prompt used for the main translation view.
    public static func systemPrompt(for settings: TranslationSettings) -> String {
        var parts: [String] = []

        parts.append("You are a professional translator and linguist.")
        parts.append("Translate the following text into \(settings.targetLanguage).")
        parts.append("IMPORTANT: Respond with plain text only. Do NOT use Markdown, bold, headers, bullet points, or any formatting. Do NOT repeat the source text or label sections.")

        switch settings.detailLevel {
        case .concise:
            parts.append("Provide only the exact translation variants separated by commas. Nothing else \u{2014} no explanations, no notes, no examples.")

        case .standard:
            parts.append("First line: the word or phrase in its dictionary/normal form, with gender or number indication in parentheses if applicable in the target language (e.g. \"(m)\", \"(f)\", \"(n)\", \"(pl)\").")
            parts.append("Second line: a brief description of the meaning in the target language.")

        case .detailed:
            parts.append("First line: the word or phrase in its dictionary/normal form, with gender or number indication in parentheses if applicable in the target language (e.g. \"(m)\", \"(f)\", \"(n)\", \"(pl)\").")
            parts.append("Following lines: a thorough description of the meaning, nuances, connotations, and alternative translations in the target language. Include notes on register (formal/informal), regional usage, and any idiomatic aspects.")
        }

        if settings.includeExamples {
            parts.append("After the translation, on new lines add 2-3 short usage examples showing the word or phrase in different contexts. Each example on its own line.")
        }

        parts.append("If the source text is already in \(settings.targetLanguage), translate it into English instead.")

        return parts.joined(separator: " ")
    }

    /// Short prompt that returns ONLY the concise comma-separated translation.
    /// Used to populate the `shortTranslation` field for history display.
    public static func shortTranslationPrompt(targetLanguage: String) -> String {
        [
            "You are a translator.",
            "Translate the following text into \(targetLanguage).",
            "Provide ONLY the exact translation variants separated by commas. Nothing else \u{2014} no explanations, no notes, no examples, no formatting.",
            "If the source text is already in \(targetLanguage), translate it into English instead."
        ].joined(separator: " ")
    }
}
