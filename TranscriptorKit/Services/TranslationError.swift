import Foundation

public enum TranslationError: LocalizedError {
    case noAPIKey(provider: TranslationSettings.Provider)
    case emptyResponse
    case refused(explanation: String?)
    case onDeviceUnavailable(String)
    case invalidResponse
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
        case .apiError(let statusCode, let message):
            switch statusCode {
            case 400: "Bad request: \(message)"
            case 401, 403: "Invalid API key. Please check your key in Settings."
            case 429: "Rate limit exceeded: \(message)"
            case 500...599: "Server error (\(statusCode)): \(message) Please try again later."
            default: "API error (\(statusCode)): \(message)"
            }
        }
    }
}
