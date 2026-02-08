import Foundation

public actor GeminiService {

    public static let shared = GeminiService()

    private init() {}

    // MARK: - Non-streaming

    public func translate(text: String, settings: TranslationSettings) async throws -> String {
        let apiKey = try requireAPIKey()
        let request = buildURLRequest(text: text, settings: settings, stream: false, apiKey: apiKey)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = geminiResponse.text else {
            throw TranslationError.emptyResponse
        }
        return content
    }

    // MARK: - Streaming

    public nonisolated func translateStreaming(
        text: String,
        settings: TranslationSettings
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = try KeychainService.shared.loadAPIKey().orThrow(TranslationError.noAPIKey)
                    let request = Self.buildURLRequestStatic(
                        text: text, settings: settings, stream: true, apiKey: apiKey
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        if let errorData = errorBody.data(using: .utf8),
                           let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: errorData) {
                            continuation.finish(throwing: TranslationError.apiError(
                                statusCode: httpResponse.statusCode,
                                message: errorResponse.error.message
                            ))
                        } else {
                            continuation.finish(throwing: TranslationError.apiError(
                                statusCode: httpResponse.statusCode,
                                message: errorBody.isEmpty ? "Unknown error" : errorBody
                            ))
                        }
                        return
                    }

                    // Gemini SSE: "data: {json}\n\n"
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)

                        guard !jsonString.isEmpty,
                              let jsonData = jsonString.data(using: .utf8) else { continue }

                        do {
                            let chunk = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)
                            if let text = chunk.text {
                                continuation.yield(text)
                            }
                        } catch {
                            // Skip malformed chunks
                            continue
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Short translation (for history)

    /// Fetch a concise comma-separated translation for history display.
    public func translateShort(text: String, targetLanguage: String, model: TranslationSettings.GeminiModel) async throws -> String {
        let apiKey = try requireAPIKey()
        let urlString = "\(AppConstants.geminiBaseURL)/\(model.rawValue):generateContent?key=\(apiKey)"

        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body = GeminiRequest(
            systemPrompt: PromptBuilder.shortTranslationPrompt(targetLanguage: targetLanguage),
            userText: text
        )
        request.httpBody = try? JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = geminiResponse.text else {
            throw TranslationError.emptyResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private helpers

    private func requireAPIKey() throws -> String {
        guard let key = KeychainService.shared.loadAPIKey(), !key.isEmpty else {
            throw TranslationError.noAPIKey
        }
        return key
    }

    private func buildURLRequest(text: String, settings: TranslationSettings, stream: Bool, apiKey: String) -> URLRequest {
        Self.buildURLRequestStatic(text: text, settings: settings, stream: stream, apiKey: apiKey)
    }

    private static func buildURLRequestStatic(text: String, settings: TranslationSettings, stream: Bool, apiKey: String) -> URLRequest {
        let correctedURL: String
        if stream {
            correctedURL = "\(AppConstants.geminiBaseURL)/\(settings.model.rawValue):streamGenerateContent?alt=sse&key=\(apiKey)"
        } else {
            correctedURL = "\(AppConstants.geminiBaseURL)/\(settings.model.rawValue):generateContent?key=\(apiKey)"
        }

        var request = URLRequest(url: URL(string: correctedURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body = GeminiRequest(
            systemPrompt: PromptBuilder.systemPrompt(for: settings),
            userText: text
        )

        request.httpBody = try? JSONEncoder().encode(body)
        return request
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
