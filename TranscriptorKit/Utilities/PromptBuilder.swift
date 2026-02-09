import Foundation

public enum PromptBuilder {

    /// Full translation prompt used for the main translation view.
    public static func systemPrompt(for settings: TranslationSettings) -> String {
        var parts: [String] = []

        parts.append("You are a professional translator and linguist.")
        parts.append("Translate the following text into \(settings.targetLanguage).")
        parts.append("First, identify the source language and state it on the first line, e.g. \"Language: Polish\".")

        switch settings.detailLevel {
        case .concise:
            parts.append("""
            Then provide:
            - The word/phrase in its dictionary (normal) form.
            - Its grammatical type (noun, verb, adjective, etc.) and gender/number if applicable (m, f, n, pl).
            - Translation variants separated by commas.
            - Brief note on the context where this word/phrase is typically used.
            Keep it compact. No examples, no numbered lists.
            """)

        case .standard:
            parts.append("""
            Then provide:
            - The word/phrase in its dictionary (normal) form.
            - Its grammatical type (noun, verb, adjective, etc.) and gender/number if applicable (m, f, n, pl).
            - Translation variants separated by commas.
            - Brief note on the context where this word/phrase is typically used.
            Then add a section "Examples:" with an unnumbered list of usage examples. Each example should be a sentence in the original language followed by a dash and its translation. Like this:
            Examples:
            * Lustrował teren. — He was surveying the area.
            * Lustrował dokumenty. — He was thoroughly reviewing the documents.
            Provide 3-5 examples showing different contexts.
            """)

        case .detailed:
            parts.append("""
            Then provide:
            - The word/phrase in its dictionary (normal) form.
            - Its grammatical type (noun, verb, adjective, etc.) and gender/number if applicable (m, f, n, pl).
            - Translation variants separated by commas.
            - Brief note on the context where this word/phrase is typically used.
            Then provide a detailed numbered list of each meaning/sense of the word. Each numbered item should contain the variant of the word/phrase with its translation. Under each numbered item, add an unnumbered list with 2-3 usage examples (sentence in original language — translation). Like this:
            1. lustrować (осматривать, обследовать) — to inspect, to survey
            * Lustrował teren. — He was surveying the area.
            * Lustrował okolicę. — He was inspecting the surroundings.
            2. lustrować (проверять) — to review, to examine
            * Lustrował dokumenty. — He was thoroughly reviewing the documents.
            Cover all significant meanings of the word.
            """)
        }

        parts.append("If the source text is already in \(settings.targetLanguage), translate it into English instead.")

        return parts.joined(separator: "\n")
    }

    /// Short prompt that returns ONLY the concise comma-separated translation.
    /// Used to populate the `shortTranslation` field for history display.
    public static func shortTranslationPrompt(targetLanguage: String) -> String {
        [
            "You are a translator.",
            "Translate the following text into \(targetLanguage).",
            "Provide ONLY the exact translation variants separated by commas. Nothing else — no explanations, no notes, no examples, no formatting.",
            "If the source text is already in \(targetLanguage), translate it into English instead."
        ].joined(separator: " ")
    }
}
