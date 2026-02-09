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
        Use Markdown formatting in your response: **bold** for the normal form and key terms, \
        bullet lists (* item) for examples.
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
            Then add examples. The section header must be in \(lang) (e.g. "Примеры:" for Russian, \
            "Ejemplos:" for Spanish, "Examples:" for English). \
            Use an unnumbered bullet list. Each example: a sentence in the original language, \
            followed by an em-dash (—) and its translation into \(lang). Like this:
            * Lustrował teren. — Он осматривал территорию.
            * Lustrował dokumenty. — Он тщательно проверял документы.
            Provide 3-5 examples showing different contexts.
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
            Under each numbered item, add an unnumbered bullet list with 2-3 usage examples \
            (sentence in original language — translation into \(lang)). Like this:
            1. lustrować (осматривать, обследовать)
            * Lustrował teren. — Он осматривал территорию.
            * Lustrował okolicę. — Он осматривал окрестности.
            2. lustrować (проверять, изучать)
            * Lustrował dokumenty. — Он тщательно проверял документы.
            Cover all significant meanings of the word.
            """)
        }

        parts.append("If the source text is already in \(lang), translate it into English instead.")

        return parts.joined(separator: "\n")
    }

    /// Prompt for structured JSON meta extraction (source language + short translation).
    public static func metaExtractionPrompt(targetLanguage: String) -> String {
        [
            "You are a professional translator.",
            "Identify the source language of the given text and provide a concise translation into \(targetLanguage).",
            "For sourceLanguage: state the language name in \(targetLanguage) followed by its ISO 639-1 code in parentheses (e.g. \"Польский (pl)\" if target is Russian).",
            "For shortTranslation: provide only the main translation variants separated by commas, without any explanations, formatting, or extra text.",
            "If the source text is already in \(targetLanguage), translate into English instead."
        ].joined(separator: " ")
    }
}
