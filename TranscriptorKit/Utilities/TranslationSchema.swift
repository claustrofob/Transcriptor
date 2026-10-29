import Foundation

/// Response schemas for translation requests, shared by all providers.
/// Written in Gemini's dialect (uppercase types); use `JSONSchema.standardized()` for standard JSON Schema.
public enum TranslationSchema {

    /// One schema for every input: the model reports the class in "textType" and leaves the
    /// dictionary fields empty for free text.
    public static func schema(lang: String) -> JSONSchema {
        fullSchema(lang: lang)
    }

    private static let generationOrder = [
        "textType", "sourceLanguage", "normalForm", "synonyms", "translatedText", "shortTranslation", "examples",
    ]

    private static func fullSchema(lang: String) -> JSONSchema {
        let exampleSchema = JSONSchema(
            type: "OBJECT",
            properties: [
                "original": JSONSchema(
                    type: "STRING",
                    description: "A natural sentence in the source language using an inflected or conjugated form of the word as it appears in real speech — not necessarily the lemma form itself."
                ),
                "translation": JSONSchema(type: "STRING", description: "Same sentence translated into \(lang)")
            ],
            required: ["original", "translation"],
            propertyOrdering: ["original", "translation"]
        )

        return JSONSchema(
            type: "OBJECT",
            properties: [
                "textType": JSONSchema(
                    type: "STRING",
                    description: "Class of the input, decided before translating: \"word\", \"expression\" or \"freeText\".",
                    enumValues: TranslationType.allCases.map(\.rawValue)
                ),
                "normalForm": JSONSchema(
                    type: "STRING",
                    description: "Empty string for free text. The lemma (lexeme) of the input word — the canonical base form as found in a dictionary. MUST be in the SOURCE language, NEVER in \(lang). CRITICAL: Always return the lemma even when the user typed an inflected form. Rules: noun → nominative singular; verb → infinitive; adjective → nominative singular masculine; pronoun → nominative. Examples: 'biegałem'→'biegać', 'dogs'→'dog', 'красивого'→'красивый', 'gelaufen'→'laufen'."
                ),
                "synonyms": JSONSchema(
                    type: "STRING",
                    description: "Synonyms in the SOURCE language (same language as input), NOT in \(lang). Comma-separated. Empty string if none or for free text."
                ),
                "translatedText": JSONSchema(
                    type: "STRING",
                    description: "Full translation and explanation. MUST be written entirely in \(lang)."
                ),
                "sourceLanguage": JSONSchema(
                    type: "STRING",
                    description: "ISO 639-1 code of the source language: two lowercase letters only, e.g. \"pl\"."
                ),
                "shortTranslation": JSONSchema(
                    type: "STRING",
                    description: "Brief translation variants in \(lang), comma-separated. Empty string for free text."
                ),
                "examples": JSONSchema(
                    type: "ARRAY",
                    items: exampleSchema,
                    description: "Empty array for free text. Usage examples in natural context. IMPORTANT: Vary the grammatical forms of the lemma across examples — use different tenses, cases, persons, numbers, etc. Do NOT repeat the same inflected form in multiple examples."
                )
            ],
            required: generationOrder,
            // Class first, so every other field is written for the class already decided.
            propertyOrdering: generationOrder
        )
    }
}
