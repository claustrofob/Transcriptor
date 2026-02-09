import Foundation

public enum PromptBuilder {

    /// Full translation prompt used for the main translation view (streaming, Markdown output).
    public static func systemPrompt(for settings: TranslationSettings) -> String {
        let lang = settings.targetLanguage

        var parts: [String] = []

        parts.append("You are a professional translator and linguist.")
        parts.append("Translate the following text into \(lang).")
        parts.append("""
        CRITICAL LANGUAGE RULE: Your ENTIRE response — all labels, grammatical terms, section headers, \
        and explanations — MUST be written in \(lang). \
        The ONLY exception is the original text and example sentences in the source language. \
        Never use English or any third language for labels or terms.
        """)
        parts.append("""
        Use Markdown formatting in your response: **bold** for the normal form and key terms.
        """)

        switch settings.detailLevel {
        case .concise:
            parts.append("""
            Provide:
            - The word/phrase in its dictionary (normal) form in **bold**.
            - Its grammatical type and gender/number in \(lang) (e.g. if target is Russian: \
            "прилагательное", "глагол", "существительное (м.р.)", "причастие (ж.р., ед.ч.)").
            - Translation variants separated by commas.
            - Brief note on the context where this word/phrase is typically used.
            Keep it compact. No examples, no numbered lists.
            """)

        case .standard:
            parts.append("""
            Provide:
            - The word/phrase in its dictionary (normal) form in **bold**.
            - Its grammatical type and gender/number in \(lang) (e.g. if target is Russian: \
            "прилагательное", "глагол", "существительное (м.р.)", "причастие (ж.р., ед.ч.)").
            - Translation variants separated by commas.
            - Brief note on the context where this word/phrase is typically used.
            Do NOT include any examples — they will be provided separately.
            """)

        case .detailed:
            parts.append("""
            Provide:
            - The word/phrase in its dictionary (normal) form in **bold**.
            - Its grammatical type and gender/number in \(lang) (e.g. if target is Russian: \
            "прилагательное", "глагол", "существительное (м.р.)", "причастие (ж.р., ед.ч.)").
            - Translation variants separated by commas.
            - Brief note on the context where this word/phrase is typically used.
            Then provide a detailed numbered list of each meaning/sense of the word. \
            Each numbered item: the word variant with its translation into \(lang). \
            Do NOT include usage examples — they will be provided separately.
            """)
        }

        parts.append("If the source text is already in \(lang), translate it into English instead.")

        return parts.joined(separator: "\n")
    }

    /// Prompt for structured JSON meta extraction (source language + short translation + examples).
    public static func metaExtractionPrompt(targetLanguage: String, detailLevel: TranslationSettings.DetailLevel) -> String {
        var parts = [
            "You are a professional translator.",
            "Identify the source language of the given text and provide a concise translation into \(targetLanguage).",
            "For sourceLanguage: state the language name in \(targetLanguage) followed by its ISO 639-1 code in parentheses (e.g. \"Польский (pl)\" if target is Russian).",
            "For shortTranslation: provide only the main translation variants separated by commas, without any explanations, formatting, or extra text.",
            "If the source text is already in \(targetLanguage), translate into English instead."
        ]

        switch detailLevel {
        case .concise:
            parts.append("For examples: return an empty array [].")
        case .standard:
            parts.append("For examples: provide 3-5 usage examples in different contexts. Each example has 'original' (sentence in the source language) and 'translation' (translation into \(targetLanguage)).")
        case .detailed:
            parts.append("For examples: provide 5-8 usage examples covering all significant meanings of the word/phrase. Each example has 'original' (sentence in the source language) and 'translation' (translation into \(targetLanguage)).")
        }

        return parts.joined(separator: " ")
    }
}
