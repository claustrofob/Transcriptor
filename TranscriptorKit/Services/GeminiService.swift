import Foundation

public actor GeminiService {

    public static let shared = GeminiService()

    private init() {}

    // MARK: - Unified translation (single JSON request)

    /// Performs translation in a single request using Gemini JSON mode.
    /// Returns structured `TranslationMeta` with translatedText, sourceLanguage, and optionally normalForm, synonyms, examples.
    /// Translates `text` using Gemini JSON mode.
    /// Pass `sourceLanguage` (English name, e.g. "Polish") to override Gemini's auto-detection.
    public func translateFull(
        text: String,
        settings: TranslationSettings,
        sourceLanguage: String? = nil
    ) async throws -> TranslationMeta {
        let apiKey = try requireAPIKey()
        let urlString = "\(AppConstants.geminiBaseURL)/\(settings.geminiModel.rawValue):generateContent?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw TranslationError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let config = GenerationConfig(
            responseMimeType: "application/json",
            responseSchema: TranslationSchema.schema(lang: settings.targetLanguage)
        )

        let body = GeminiRequest(
            systemPrompt: PromptBuilder.translationPrompt(for: settings, sourceLanguageOverride: sourceLanguage),
            userText: text,
            generationConfig: config
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let jsonString = geminiResponse.text,
              let jsonData = jsonString.data(using: .utf8) else {
            throw TranslationError.emptyResponse
        }

        return try JSONDecoder().decode(TranslationMeta.self, from: jsonData)
    }

    // MARK: - Private helpers

    private func requireAPIKey() throws -> String {
        guard let key = KeychainService.shared.loadAPIKey(for: .google), !key.isEmpty else {
            throw TranslationError.noAPIKey(provider: .google)
        }
        return key
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
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

// MARK: - Errors

public enum TranslationError: LocalizedError {
    case noAPIKey(provider: TranslationSettings.Provider)
    case emptyResponse
    case refused(explanation: String?)
    case onDeviceUnavailable(String)
    case invalidResponse
    case networkError(Error)
    case apiError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            "API key not configured. Please set your \(provider.displayName) API key in Settings."
        case .emptyResponse:
            "Received an empty response from the server."
        case .onDeviceUnavailable(let reason):
            reason
        case .refused(let explanation):
            explanation.map { "The model declined to translate this text: \($0)" }
                ?? "The model declined to translate this text."
        case .invalidResponse:
            "Invalid response from the server."
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            switch statusCode {
            case 400: "Bad request: \(message)"
            case 401, 403: "Invalid API key. Please check your key in Settings."
            case 429: "Rate limit exceeded: \(message)"
            case 500...599: "Server error (\(statusCode)). Please try again later."
            default: "API error (\(statusCode)): \(message)"
            }
        }
    }
}

// MARK: - Optional helper

extension Optional {
    func orThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }
}
