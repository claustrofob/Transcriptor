import Foundation

public enum PromptBuilder {

    /// Unified translation prompt — returns JSON with all translation data.
    /// All fields are plain text — no Markdown formatting anywhere.
    /// Pass `sourceLanguageOverride` to force a specific source language when Gemini's auto-detection was incorrect.
    public static func translationPrompt(
        for settings: TranslationSettings,
        translationType: TranslationType,
        sourceLanguageOverride: String? = nil
    ) -> String {
        let lang = settings.targetLanguage

        let base: String
        switch translationType {
        case .word:
            base = wordPrompt(settings: settings, lang: lang)
        case .expression:
            base = expressionPrompt(settings: settings, lang: lang)
        case .freeText:
            base = freeTextPrompt(lang: lang)
        }

        guard let src = sourceLanguageOverride else { return base }
        let override = "SOURCE LANGUAGE OVERRIDE: The input text is in \(src). Treat it strictly as \(src) and translate from \(src) to \(lang). Disregard any rule that would redirect the translation into English.\n\n"
        return override + base
    }

    // MARK: - Word prompt

    private static func wordPrompt(settings: TranslationSettings, lang: String) -> String {
        """
        You are a professional translator. You translate words and phrases into \(lang).
        ALL your output MUST be in \(lang) unless specified otherwise below.

        CRITICAL: The translation target language is \(lang). Write all translations, explanations, and grammatical labels in \(lang).

        FORMATTING: No Markdown. No **, *, _, #, backticks. Plain text only. Use \\n for line breaks. Numbered lists: "1. ", "2. ".

        LANGUAGE RULES FOR EACH JSON FIELD (FOLLOW STRICTLY):
        • "normalForm" → MUST be in the SOURCE LANGUAGE (the language of the input, NOT \(lang)). Dictionary/lemma form: noun → nominative singular; adjective → nominative singular masculine; verb → infinitive; pronoun → dictionary form. If already in normal form, repeat as-is.
        • "synonyms" → MUST be in the SOURCE LANGUAGE (the language of the input, NOT \(lang)). These are synonyms of the original word, written in the SAME language as the input. NEVER translate synonyms into \(lang). Comma-separated. Empty string if none.
        • "translatedText" → MUST be in \(lang). This is the main translation output. Everything here MUST be written in \(lang): grammatical labels, meanings, explanations. NEVER write this field in English or any other language except \(lang).
        • "shortTranslation" → MUST be in \(lang). Only the main translation variants separated by commas. No explanations.
        • "sourceLanguage" → MUST be in \(lang). Language name in \(lang) + ISO 639-1 code in parentheses (example: "Польский (pl)" when \(lang) is Russian).
        • "examples" → "original" MUST be in the SOURCE LANGUAGE, "translation" MUST be in \(lang).

        CONTENT OF "translatedText" (write ALL of this in \(lang)):
        \(translatedTextInstructions(lang: lang))

        CONTENT OF "examples":
        \(examplesInstructions(lang: lang))

        If the input is already in \(lang), translate into English instead (English becomes the target for all fields above).

        REMINDER: translatedText, shortTranslation, sourceLanguage, and example translations MUST be in \(lang). Do NOT use English for these fields.
        """
    }

    // MARK: - Expression prompt

    private static func expressionPrompt(settings: TranslationSettings, lang: String) -> String {
        """
        You are a professional translator. You translate expressions and idioms into \(lang).
        ALL your output MUST be in \(lang) unless specified otherwise below.

        CRITICAL: The translation target language is \(lang). Write all translations, explanations, and grammatical labels in \(lang).

        FORMATTING: No Markdown. No **, *, _, #, backticks. Plain text only. Use \\n for line breaks. Numbered lists: "1. ", "2. ".

        LANGUAGE RULES FOR EACH JSON FIELD (FOLLOW STRICTLY):
        • "normalForm" → MUST be in the SOURCE LANGUAGE (the language of the input, NOT \(lang)). The canonical form of the expression/idiom in the source language. For verb phrases, use the infinitive form. For idioms, use the standard dictionary form.
        • "synonyms" → MUST be in the SOURCE LANGUAGE (the language of the input, NOT \(lang)). Alternative expressions or idioms with similar meaning in the SAME language as the input. NEVER translate into \(lang). Comma-separated. Empty string if none.
        • "translatedText" → MUST be in \(lang). This is the main translation output. Everything here MUST be written in \(lang): meaning, equivalent expressions, explanations. NEVER write this field in English or any other language except \(lang).
        • "shortTranslation" → MUST be in \(lang). Only the main translation variants separated by commas. No explanations.
        • "sourceLanguage" → MUST be in \(lang). Language name in \(lang) + ISO 639-1 code in parentheses.
        • "examples" → "original" MUST be in the SOURCE LANGUAGE, "translation" MUST be in \(lang).

        CONTENT OF "translatedText" (write ALL of this in \(lang)):
        \(translatedTextInstructions(lang: lang))

        CONTENT OF "examples":
        \(examplesInstructions(lang: lang))

        If the input is already in \(lang), translate into English instead (English becomes the target for all fields above).

        REMINDER: translatedText, shortTranslation, sourceLanguage, and example translations MUST be in \(lang). Do NOT use English for these fields.
        """
    }

    // MARK: - Free text prompt

    private static func freeTextPrompt(lang: String) -> String {
        """
        You are a professional translator. Translate the given text into \(lang).
        Provide an accurate, natural-sounding translation.

        FORMATTING: No Markdown. No **, *, _, #, backticks. Plain text only.

        LANGUAGE RULES FOR EACH JSON FIELD:
        • "translatedText" → MUST be in \(lang). The full translation of the input text.
        • "sourceLanguage" → MUST be in \(lang). Language name in \(lang) + ISO 639-1 code in parentheses.

        If the input is already in \(lang), translate into English instead.
        """
    }

    // MARK: - Result format instructions

    private static func translatedTextInstructions(lang: String) -> String {
        """
        - Grammatical type and gender/number in \(lang).
        - Translation variants separated by commas.
        - Brief context note.
        - Numbered list of each meaning/sense with its translation in \(lang).
        Do NOT include usage examples here — they go into "examples".
        """
    }

    private static func examplesInstructions(lang: String) -> String {
        "5-8 examples covering all meanings. \"original\" = sentence in source language, \"translation\" = same sentence translated into \(lang)."
    }
}
