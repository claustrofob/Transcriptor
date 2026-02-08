import Foundation

// MARK: - Request

public struct GeminiRequest: Encodable, Sendable {
    public let systemInstruction: SystemInstruction?
    public let contents: [Content]

    public struct SystemInstruction: Encodable, Sendable {
        public let parts: [Part]
    }

    public struct Content: Encodable, Sendable {
        public let role: String
        public let parts: [Part]
    }

    public struct Part: Encodable, Sendable {
        public let text: String
    }

    public init(systemPrompt: String, userText: String) {
        self.systemInstruction = SystemInstruction(
            parts: [Part(text: systemPrompt)]
        )
        self.contents = [
            Content(role: "user", parts: [Part(text: userText)])
        ]
    }
}

// MARK: - Response (non-streaming)

public struct GeminiResponse: Decodable, Sendable {
    public let candidates: [Candidate]?
    public let usageMetadata: UsageMetadata?

    public struct Candidate: Decodable, Sendable {
        public let content: ContentResponse?
        public let finishReason: String?
    }

    public struct ContentResponse: Decodable, Sendable {
        public let parts: [PartResponse]?
        public let role: String?
    }

    public struct PartResponse: Decodable, Sendable {
        public let text: String?
    }

    public struct UsageMetadata: Decodable, Sendable {
        public let promptTokenCount: Int?
        public let candidatesTokenCount: Int?
        public let totalTokenCount: Int?
    }

    /// Extract text from first candidate
    public var text: String? {
        candidates?.first?.content?.parts?.compactMap(\.text).joined()
    }
}

// MARK: - Error response

public struct GeminiErrorResponse: Decodable, Sendable {
    public let error: GeminiError

    public struct GeminiError: Decodable, Sendable {
        public let code: Int
        public let message: String
        public let status: String?
    }
}
