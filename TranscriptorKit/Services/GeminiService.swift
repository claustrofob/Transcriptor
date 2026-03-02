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
        translationType: TranslationType,
        sourceLanguage: String? = nil
    ) async throws -> TranslationMeta {
        let apiKey = try requireAPIKey()
        let urlString = "\(AppConstants.geminiBaseURL)/\(settings.model.rawValue):generateContent?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw TranslationError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let lang = settings.targetLanguage
        let schema: JSONSchema

        switch translationType {
        case .word, .expression:
            schema = buildFullSchema(lang: lang)
        case .freeText:
            schema = buildFreeTextSchema(lang: lang)
        }

        let config = GenerationConfig(
            responseMimeType: "application/json",
            responseSchema: schema
        )

        let body = GeminiRequest(
            systemPrompt: PromptBuilder.translationPrompt(for: settings, translationType: translationType, sourceLanguageOverride: sourceLanguage),
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

    // MARK: - JSON Schemas

    private func buildFullSchema(lang: String) -> JSONSchema {
        let exampleSchema = JSONSchema(
            type: "OBJECT",
            properties: [
                "original": JSONSchema(
                    type: "STRING",
                    description: "A natural sentence in the source language using an inflected or conjugated form of the word as it appears in real speech — not necessarily the lemma form itself."
                ),
                "translation": JSONSchema(type: "STRING", description: "Same sentence translated into \(lang)")
            ],
            required: ["original", "translation"]
        )

        return JSONSchema(
            type: "OBJECT",
            properties: [
                "normalForm": JSONSchema(
                    type: "STRING",
                    description: "The lemma (lexeme) of the input word — the canonical base form as found in a dictionary. MUST be in the SOURCE language, NEVER in \(lang). CRITICAL: Always return the lemma even when the user typed an inflected form. Rules: noun → nominative singular; verb → infinitive; adjective → nominative singular masculine; pronoun → nominative. Examples: 'biegałem'→'biegać', 'dogs'→'dog', 'красивого'→'красивый', 'gelaufen'→'laufen'."
                ),
                "synonyms": JSONSchema(
                    type: "STRING",
                    description: "Synonyms in the SOURCE language (same language as input), NOT in \(lang). Comma-separated. Empty string if none."
                ),
                "translatedText": JSONSchema(
                    type: "STRING",
                    description: "Full translation and explanation. MUST be written entirely in \(lang)."
                ),
                "sourceLanguage": JSONSchema(
                    type: "STRING",
                    description: "Name of the source language written in \(lang) with ISO 639-1 code in parentheses."
                ),
                "shortTranslation": JSONSchema(
                    type: "STRING",
                    description: "Brief translation variants in \(lang), comma-separated."
                ),
                "examples": JSONSchema(
                    type: "ARRAY",
                    items: exampleSchema,
                    description: "Usage examples in natural context. IMPORTANT: Vary the grammatical forms of the lemma across examples — use different tenses, cases, persons, numbers, etc. Do NOT repeat the same inflected form in multiple examples."
                )
            ],
            required: ["normalForm", "synonyms", "translatedText", "sourceLanguage", "shortTranslation", "examples"]
        )
    }

    private func buildFreeTextSchema(lang: String) -> JSONSchema {
        JSONSchema(
            type: "OBJECT",
            properties: [
                "translatedText": JSONSchema(
                    type: "STRING",
                    description: "Full translation of the input text. MUST be written entirely in \(lang)."
                ),
                "sourceLanguage": JSONSchema(
                    type: "STRING",
                    description: "Name of the source language written in \(lang) with ISO 639-1 code in parentheses."
                )
            ],
            required: ["translatedText", "sourceLanguage"]
        )
    }

    // MARK: - Private helpers

    private func requireAPIKey() throws -> String {
        guard let key = KeychainService.shared.loadAPIKey(), !key.isEmpty else {
            throw TranslationError.noAPIKey
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
    case noAPIKey
    case emptyResponse
    case invalidResponse
    case networkError(Error)
    case apiError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            "API key not configured. Please set your Google AI API key in Settings."
        case .emptyResponse:
            "Received an empty response from the server."
        case .invalidResponse:
            "Invalid response from the server."
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            switch statusCode {
            case 400: "Bad request: \(message)"
            case 403: "Invalid API key. Please check your key in Settings."
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
