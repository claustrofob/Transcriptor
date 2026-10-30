import Foundation

/// JSON requests to the cloud providers' APIs, shared by `GeminiService` and `ClaudeService`.
enum APIClient {

    /// The provider's key from Keychain; `TranslationError.noAPIKey` if none is set.
    static func apiKey(for provider: TranslationSettings.Provider) throws -> String {
        guard let key = KeychainService.shared.loadAPIKey(for: provider), !key.isEmpty else {
            throw TranslationError.noAPIKey(provider: provider)
        }
        return key
    }

    /// POSTs `body` as JSON and decodes the response. A non-2xx status throws `TranslationError.apiError`
    /// with the message from the provider's error body, if it has one.
    static func post<Response: Decodable>(
        to url: URL,
        headers: [String: String],
        body: Data,
        timeout: TimeInterval
    ) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error.message
            throw TranslationError.apiError(
                statusCode: httpResponse.statusCode,
                message: message ?? "HTTP \(httpResponse.statusCode)"
            )
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

/// Error body of both Gemini and Claude: `{"error": {"message": "..."}}`.
struct APIErrorResponse: Decodable {
    struct Details: Decodable {
        let message: String
    }

    let error: Details
}
