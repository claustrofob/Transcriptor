import Foundation

public actor ClaudeService {

    public static let shared = ClaudeService()

    private init() {}

    // MARK: - Unified translation (single JSON request)

    /// Translates `text` with the Claude Messages API using structured outputs.
    /// Pass `sourceLanguage` (English name, e.g. "Polish") to override auto-detection.
    public func translateFull(
        text: String,
        settings: TranslationSettings,
        sourceLanguage: String? = nil
    ) async throws -> TranslationMeta {
        let apiKey = try requireAPIKey()
        let model = settings.claudeModel

        guard let url = URL(string: AppConstants.claudeMessagesURL) else {
            throw TranslationError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AppConstants.claudeAPIVersion, forHTTPHeaderField: "anthropic-version")
        if model.supportsServerFallback {
            request.setValue(AppConstants.claudeFallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }
        request.timeoutInterval = 120

        let body = ClaudeRequest(
            model: model.rawValue,
            maxTokens: 16000,
            systemPrompt: PromptBuilder.translationPrompt(for: settings, sourceLanguageOverride: sourceLanguage),
            userText: text,
            effort: "medium",
            schema: TranslationSchema.schema(lang: settings.targetLanguage).standardized(),
            fallbacks: model.supportsServerFallback ? "default" : nil
        )
        request.httpBody = try body.encodedBody()

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        switch claudeResponse.stopReason {
        case "refusal":
            throw TranslationError.refused(explanation: claudeResponse.stopDetails?.explanation)
        case "max_tokens":
            throw TranslationError.invalidResponse
        default:
            break
        }

        guard let jsonData = claudeResponse.text.data(using: .utf8), !jsonData.isEmpty else {
            throw TranslationError.emptyResponse
        }

        return try JSONDecoder().decode(TranslationMeta.self, from: jsonData)
    }

    // MARK: - Private helpers

    private func requireAPIKey() throws -> String {
        guard let key = KeychainService.shared.loadAPIKey(for: .anthropic), !key.isEmpty else {
            throw TranslationError.noAPIKey(provider: .anthropic)
        }
        return key
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw TranslationError.apiError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.error.message
                )
            }
            throw TranslationError.apiError(
                statusCode: httpResponse.statusCode,
                message: "HTTP \(httpResponse.statusCode)"
            )
        }
    }
}
