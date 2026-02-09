import Foundation

// MARK: - Request

public struct GeminiRequest: Encodable, Sendable {
    public let systemInstruction: SystemInstruction?
    public let contents: [Content]
    public let generationConfig: GenerationConfig?

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

    /// Standard request (streaming/non-streaming without JSON mode)
    public init(systemPrompt: String, userText: String) {
        self.systemInstruction = SystemInstruction(
            parts: [Part(text: systemPrompt)]
        )
        self.contents = [
            Content(role: "user", parts: [Part(text: userText)])
        ]
        self.generationConfig = nil
    }

    /// Request with JSON mode (structured output)
    public init(systemPrompt: String, userText: String, generationConfig: GenerationConfig) {
        self.systemInstruction = SystemInstruction(
            parts: [Part(text: systemPrompt)]
        )
        self.contents = [
            Content(role: "user", parts: [Part(text: userText)])
        ]
        self.generationConfig = generationConfig
    }
}

// MARK: - Generation Config (JSON mode)

public struct GenerationConfig: Encodable, Sendable {
    public let responseMimeType: String
    public let responseSchema: JSONSchema

    public init(responseMimeType: String, responseSchema: JSONSchema) {
        self.responseMimeType = responseMimeType
        self.responseSchema = responseSchema
    }

    private enum CodingKeys: String, CodingKey {
        case responseMimeType = "response_mime_type"
        case responseSchema = "response_schema"
    }
}

// MARK: - JSON Schema

public struct JSONSchema: Encodable, Sendable {
    public let type: String
    public let properties: [String: JSONSchema]?
    public let required: [String]?
    public let description: String?

    public init(
        type: String,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.description = description
    }
}

// MARK: - Translation Meta (JSON extraction result)

public struct TranslationMeta: Decodable, Sendable {
    public let sourceLanguage: String
    public let shortTranslation: String
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
