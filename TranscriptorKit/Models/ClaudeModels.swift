import Foundation

// MARK: - Request

public struct ClaudeRequest: Encodable, Sendable {
    public let model: String
    public let maxTokens: Int
    public let system: String
    public let messages: [Message]
    public let outputConfig: OutputConfig
    /// Server-side refusal fallback ("default" routes by refusal category). Requires the fallback beta header.
    public let fallbacks: String?

    public struct Message: Encodable, Sendable {
        public let role: String
        public let content: String
    }

    public struct OutputConfig: Encodable, Sendable {
        public let effort: String
        public let format: Format
    }

    /// Structured output: the response text is JSON matching `schema`.
    public struct Format: Encodable, Sendable {
        public let type: String
        public let schema: JSONSchema

        private enum CodingKeys: String, CodingKey { case type, schema }

        /// JSONEncoder doesn't keep key order, and Claude generates properties in schema order,
        /// so the schema is written as a placeholder and spliced in by `encodedBody()`.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(ClaudeRequest.schemaPlaceholder, forKey: .schema)
        }
    }

    static let schemaPlaceholder = "__ordered_json_schema__"

    /// The request as JSON, with the schema's keys in generation order.
    public func encodedBody() throws -> Data {
        let json = String(decoding: try JSONEncoder().encode(self), as: UTF8.self)
        let spliced = json.replacingOccurrences(
            of: "\"\(Self.schemaPlaceholder)\"",
            with: try outputConfig.format.schema.orderedJSONString()
        )
        return Data(spliced.utf8)
    }

    public init(model: String, maxTokens: Int, systemPrompt: String, userText: String, effort: String, schema: JSONSchema, fallbacks: String?) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = systemPrompt
        self.messages = [Message(role: "user", content: userText)]
        self.outputConfig = OutputConfig(effort: effort, format: Format(type: "json_schema", schema: schema))
        self.fallbacks = fallbacks
    }

    private enum CodingKeys: String, CodingKey {
        case model, system, messages, fallbacks
        case maxTokens = "max_tokens"
        case outputConfig = "output_config"
    }
}

// MARK: - Response

public struct ClaudeResponse: Decodable, Sendable {
    public let content: [ContentBlock]
    public let stopReason: String?
    public let stopDetails: StopDetails?

    /// Only `text` blocks are read; thinking and fallback blocks are skipped.
    public struct ContentBlock: Decodable, Sendable {
        public let type: String
        public let text: String?
    }

    /// Populated only when `stopReason == "refusal"`.
    public struct StopDetails: Decodable, Sendable {
        public let category: String?
        public let explanation: String?
    }

    private enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
        case stopDetails = "stop_details"
    }

    /// Concatenated text of all `text` blocks.
    public var text: String {
        content.filter { $0.type == "text" }.compactMap(\.text).joined()
    }
}

// MARK: - Error response

public struct ClaudeErrorResponse: Decodable, Sendable {
    public let error: ClaudeError

    public struct ClaudeError: Decodable, Sendable {
        public let type: String
        public let message: String
    }
}
