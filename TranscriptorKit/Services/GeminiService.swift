import Foundation

public enum GeminiService {

    /// Translates `text` in a single request using Gemini JSON mode.
    /// Pass `sourceLanguage` (English name, e.g. "Polish") to override Gemini's auto-detection.
    public static func translateFull(
        text: String,
        settings: TranslationSettings,
        sourceLanguage: String? = nil
    ) async throws -> TranslationMeta {
        let apiKey = try APIClient.apiKey(for: .google)
        guard let url = URL(string: "\(AppConstants.geminiBaseURL)/\(settings.geminiModel.rawValue):generateContent") else {
            throw TranslationError.invalidResponse
        }

        let body = GeminiRequest(
            systemPrompt: PromptBuilder.translationPrompt(for: settings, sourceLanguageOverride: sourceLanguage),
            userText: text,
            generationConfig: GenerationConfig(
                responseMimeType: "application/json",
                responseSchema: TranslationSchema.schema(lang: settings.targetLanguageName)
            )
        )
        let response: GeminiResponse = try await APIClient.post(
            to: url,
            // In a header rather than the URL's query, so the key doesn't end up in logged URLs.
            headers: ["x-goog-api-key": apiKey],
            body: try JSONEncoder().encode(body),
            timeout: 60
        )

        guard let json = response.text, !json.isEmpty else {
            throw TranslationError.emptyResponse
        }
        return try JSONDecoder().decode(TranslationMeta.self, from: Data(json.utf8))
    }
}
