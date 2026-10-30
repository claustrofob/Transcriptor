import Foundation

public enum ClaudeService {

    /// Translates `text` with the Claude Messages API using structured outputs.
    /// Pass `sourceLanguage` (English name, e.g. "Polish") to override auto-detection.
    public static func translateFull(
        text: String,
        settings: TranslationSettings,
        sourceLanguage: String? = nil
    ) async throws -> TranslationMeta {
        let apiKey = try APIClient.apiKey(for: .anthropic)
        let model = settings.claudeModel

        var headers = [
            "x-api-key": apiKey,
            "anthropic-version": AppConstants.claudeAPIVersion,
        ]
        if model.supportsServerFallback {
            headers["anthropic-beta"] = AppConstants.claudeFallbackBeta
        }

        let body = ClaudeRequest(
            model: model.rawValue,
            maxTokens: 16000,
            systemPrompt: PromptBuilder.translationPrompt(for: settings, sourceLanguageOverride: sourceLanguage),
            userText: text,
            effort: "medium",
            schema: TranslationSchema.schema(lang: settings.targetLanguageName).standardized(),
            fallbacks: model.supportsServerFallback ? "default" : nil
        )
        let response: ClaudeResponse = try await APIClient.post(
            to: AppConstants.claudeMessagesURL,
            headers: headers,
            body: try body.encodedBody(),
            timeout: 120
        )

        switch response.stopReason {
        case "refusal":
            throw TranslationError.refused(explanation: response.stopDetails?.explanation)
        case "max_tokens":
            throw TranslationError.invalidResponse
        default:
            break
        }

        guard !response.text.isEmpty else {
            throw TranslationError.emptyResponse
        }
        return try JSONDecoder().decode(TranslationMeta.self, from: Data(response.text.utf8))
    }
}
