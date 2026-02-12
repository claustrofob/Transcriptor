import Foundation

public enum PromptBuilder {

    /// Unified translation prompt — returns JSON with all translation data.
    /// All fields are plain text — no Markdown formatting anywhere.
    public static func translationPrompt(for settings: TranslationSettings) -> String {
        let lang = settings.targetLanguage

        return """
        You are a professional translator. You translate words and phrases into \(lang).
        ALL your output MUST be in \(lang) unless specified otherwise below.

        CRITICAL: The translation target language is \(lang). Write all translations, explanations, and grammatical labels in \(lang).

        FORMATTING: No Markdown. No **, *, _, #, backticks. Plain text only. Use \\n for line breaks. Numbered lists: "1. ", "2. ".

        LANGUAGE RULES FOR EACH JSON FIELD (FOLLOW STRICTLY):
        • "normalForm" → MUST be in the SOURCE LANGUAGE (the language of the input, NOT \(lang)). Dictionary/lemma form: noun → nominative singular; adjective → nominative singular masculine; verb → infinitive; pronoun → dictionary form. If already in normal form, repeat as-is. For phrases, provide the key word in normal form.
        • "synonyms" → MUST be in the SOURCE LANGUAGE (the language of the input, NOT \(lang)). These are synonyms of the original word, written in the SAME language as the input. For example, if the input is in Polish, synonyms must be Polish words. NEVER translate synonyms into \(lang). Comma-separated. Empty string if none.
        • "translatedText" → MUST be in \(lang). This is the main translation output. Everything here MUST be written in \(lang): grammatical labels, meanings, explanations. NEVER write this field in English or any other language except \(lang).
        • "shortTranslation" → MUST be in \(lang). Only the main translation variants separated by commas. No explanations.
        • "sourceLanguage" → MUST be in \(lang). Language name in \(lang) + ISO 639-1 code in parentheses (example: "Польский (pl)" when \(lang) is Russian).
        • "examples" → "original" MUST be in the SOURCE LANGUAGE, "translation" MUST be in \(lang).

        CONTENT OF "translatedText" (write ALL of this in \(lang)):
        \(translatedTextInstructions(for: settings.detailLevel, lang: lang))

        CONTENT OF "examples":
        \(examplesInstructions(for: settings.detailLevel, lang: lang))

        If the input is already in \(lang), translate into English instead (English becomes the target for all fields above).

        REMINDER: translatedText, shortTranslation, sourceLanguage, and example translations MUST be in \(lang). Do NOT use English for these fields.
        """
    }

    private static func translatedTextInstructions(for level: TranslationSettings.DetailLevel, lang: String) -> String {
        switch level {
        case .concise:
            return """
            - Grammatical type and gender/number in \(lang) (e.g. "существительное (ср.р.)", "глагол", "прилагательное (м.р.)").
            - Translation variants separated by commas.
            - Brief context note.
            Keep it compact. No examples, no numbered lists.
            """
        case .standard:
            return """
            - Grammatical type and gender/number in \(lang).
            - Translation variants separated by commas.
            - Brief context note.
            Do NOT include usage examples here — they go into "examples".
            """
        case .detailed:
            return """
            - Grammatical type and gender/number in \(lang).
            - Translation variants separated by commas.
            - Brief context note.
            - Numbered list of each meaning/sense with its translation in \(lang).
            Do NOT include usage examples here — they go into "examples".
            """
        }
    }

    private static func examplesInstructions(for level: TranslationSettings.DetailLevel, lang: String) -> String {
        switch level {
        case .concise:
            return "Return an empty array []."
        case .standard:
            return "3-5 examples. \"original\" = sentence in source language, \"translation\" = same sentence translated into \(lang)."
        case .detailed:
            return "5-8 examples covering all meanings. \"original\" = sentence in source language, \"translation\" = same sentence translated into \(lang)."
        }
    }
}
