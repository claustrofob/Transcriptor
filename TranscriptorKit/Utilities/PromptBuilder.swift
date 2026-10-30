import Foundation

public enum PromptBuilder {

    /// Cloud translation prompt: the model first classifies the input ("textType") and then returns
    /// the dictionary-style result for words and expressions or a plain translation for free text.
    /// All fields are plain text — no Markdown formatting anywhere.
    /// Pass `sourceLanguageOverride` to force a specific source language when auto-detection was incorrect.
    public static func translationPrompt(
        for settings: TranslationSettings,
        sourceLanguageOverride: String? = nil
    ) -> String {
        withOverride(sourceLanguageOverride, lang: settings.targetLanguageName, classifyingPrompt(lang: settings.targetLanguageName))
    }

    /// On-device prompt: a plain, exact translation of any input, no classification or analysis
    /// (the on-device model is too weak for the dictionary-style result).
    public static func plainTranslationPrompt(
        for settings: TranslationSettings,
        sourceLanguageOverride: String? = nil
    ) -> String {
        withOverride(sourceLanguageOverride, lang: settings.targetLanguageName, plainPrompt(lang: settings.targetLanguageName))
    }

    private static func withOverride(_ src: String?, lang: String, _ base: String) -> String {
        guard let src else { return base }
        let override = "SOURCE LANGUAGE OVERRIDE: The input text is in \(src). Treat it strictly as \(src) and translate from \(src) to \(lang). Disregard any rule that would redirect the translation into English.\n\n"
        return override + base
    }

    // MARK: - Classifying prompt

    private static func classifyingPrompt(lang: String) -> String {
        """
        You are a professional translator. You translate text into \(lang).
        ALL your output MUST be in \(lang) unless specified otherwise below.

        CRITICAL: The translation target language is \(lang). Write all translations, explanations, and grammatical labels in \(lang).

        FORMATTING: No Markdown. No **, *, _, #, backticks. Plain text only. Use \\n for line breaks. Numbered lists: "1. ", "2. ".

        STEP 1 — CLASSIFY THE INPUT before translating, and put the class into "textType":
        • "\(TranslationType.word.rawValue)" → a single word, or a word with an article, particle, preposition, pronoun or negation that works as one lexical unit. Examples: "podekscytowany", "das Haus", "Cześć!", "Nie możesz".
        • "\(TranslationType.expression.rawValue)" → a fixed multi-word expression: an idiom, set phrase, collocation or phrasal verb. Examples: "break the ice", "coûte que coûte", "в конце концов".
        • "\(TranslationType.freeText.rawValue)" → anything else: a full sentence with its own meaning, several sentences, or a longer text. Examples: "He ran fast.", "Jestem podekscytowany tą wspaniałą wiadomością."
        A short input (up to about five words) without sentence structure is "\(TranslationType.word.rawValue)" or "\(TranslationType.expression.rawValue)", not "\(TranslationType.freeText.rawValue)", even if it ends with punctuation.

        STEP 2 — TRANSLATE ACCORDING TO THE CLASS.

        For "\(TranslationType.word.rawValue)" and "\(TranslationType.expression.rawValue)", LANGUAGE RULES FOR EACH JSON FIELD (FOLLOW STRICTLY):
        • "normalForm" → MUST be in the SOURCE LANGUAGE (the language of the input, NOT \(lang)). For a word: the dictionary/lemma form — noun → nominative singular; adjective → nominative singular masculine; verb → infinitive; pronoun → dictionary form; if already in normal form, repeat as-is. For an expression: its canonical dictionary form; verb phrases in the infinitive.
        • "synonyms" → MUST be in the SOURCE LANGUAGE (the language of the input, NOT \(lang)). Synonyms of the word, or alternative expressions with a similar meaning, written in the SAME language as the input. NEVER translate synonyms into \(lang). Comma-separated. Empty string if none.
        • "translatedText" → MUST be in \(lang). This is the main translation output. Everything here MUST be written in \(lang): grammatical labels, meanings, explanations. NEVER write this field in English or any other language except \(lang).
        • "shortTranslation" → MUST be in \(lang). Only the main translation variants separated by commas. No explanations.
        • "sourceLanguage" → ISO 639-1 code of the source language only: two lowercase letters, no name (example: "pl" for Polish).
        • "examples" → "original" MUST be in the SOURCE LANGUAGE, "translation" MUST be in \(lang).

        CONTENT OF "translatedText" for words and expressions (write ALL of this in \(lang)):
        - Grammatical type and gender/number in \(lang).
        - Translation variants separated by commas.
        - Brief context note.
        - Numbered list of each meaning/sense with its translation in \(lang).
        Do NOT include usage examples here — they go into "examples".

        CONTENT OF "examples" for words and expressions:
        5-8 examples covering all meanings. "original" = sentence in source language, "translation" = same sentence translated into \(lang).

        For "\(TranslationType.freeText.rawValue)":
        • "translatedText" → MUST be in \(lang). An accurate, natural-sounding translation of the whole input, nothing else: no grammatical analysis, no explanations.
        • "sourceLanguage" → ISO 639-1 code of the source language only: two lowercase letters, no name.
        • "normalForm", "synonyms", "shortTranslation" → empty strings. "examples" → empty array.

        If the input is already in \(lang), translate into English instead (English becomes the target for all fields above).

        REMINDER: translatedText, shortTranslation, and example translations MUST be in \(lang). Do NOT use English for these fields.
        """
    }

    // MARK: - Plain prompt (on-device)

    private static func plainPrompt(lang: String) -> String {
        """
        You are a professional translator. Translate the given text into \(lang).
        Provide an accurate, natural-sounding translation.

        FORMATTING: No Markdown. No **, *, _, #, backticks. Plain text only.

        LANGUAGE RULES FOR EACH JSON FIELD:
        • "translatedText" → MUST be in \(lang). The full translation of the input text.
        • "sourceLanguage" → ISO 639-1 code of the source language only: two lowercase letters, no name (example: "pl" for Polish).

        If the input is already in \(lang), translate into English instead.
        """
    }
}
