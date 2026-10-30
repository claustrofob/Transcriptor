import Foundation

// MARK: - Request

public struct GeminiRequest: Encodable, Sendable {
    public let systemInstruction: SystemInstruction
    public let contents: [Content]
    public let generationConfig: GenerationConfig

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
    public let items: JSONSchemaBox?
    public let required: [String]?
    public let description: String?
    public let additionalProperties: Bool?
    /// Allowed values of a string; encoded as `enum` (supported by both Gemini and Claude).
    public let enumValues: [String]?
    /// Order in which the model generates the properties. Gemini otherwise goes alphabetically,
    /// so it's sent as Gemini's `propertyOrdering`. Claude and the local models follow the key order
    /// of `properties` instead, which only `orderedJSONString()` preserves (JSONEncoder doesn't).
    /// Unlisted properties go last, alphabetically.
    public let propertyOrdering: [String]?
    /// `propertyOrdering` is a Gemini extension; standard JSON Schema (Claude) only keeps the key order.
    private let encodesPropertyOrdering: Bool

    private enum CodingKeys: String, CodingKey {
        case type, properties, items, required, description, additionalProperties, propertyOrdering
        case enumValues = "enum"
    }

    private struct PropertyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(
        type: String,
        properties: [String: JSONSchema]? = nil,
        items: JSONSchema? = nil,
        required: [String]? = nil,
        description: String? = nil,
        additionalProperties: Bool? = nil,
        enumValues: [String]? = nil,
        propertyOrdering: [String]? = nil
    ) {
        self.init(
            type: type, properties: properties, items: items, required: required, description: description,
            additionalProperties: additionalProperties, enumValues: enumValues,
            propertyOrdering: propertyOrdering, encodesPropertyOrdering: true
        )
    }

    private init(
        type: String,
        properties: [String: JSONSchema]?,
        items: JSONSchema?,
        required: [String]?,
        description: String?,
        additionalProperties: Bool?,
        enumValues: [String]?,
        propertyOrdering: [String]?,
        encodesPropertyOrdering: Bool
    ) {
        self.type = type
        self.properties = properties
        self.items = items.map { JSONSchemaBox($0) }
        self.required = required
        self.description = description
        self.additionalProperties = additionalProperties
        self.enumValues = enumValues
        self.propertyOrdering = propertyOrdering
        self.encodesPropertyOrdering = encodesPropertyOrdering
    }

    /// Property names in generation order: `propertyOrdering` first, then the rest alphabetically.
    var orderedPropertyNames: [String] {
        guard let properties else { return [] }
        let listed = (propertyOrdering ?? []).filter { properties[$0] != nil }
        return listed + properties.keys.filter { !listed.contains($0) }.sorted()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if let properties {
            var nested = container.nestedContainer(keyedBy: PropertyKey.self, forKey: .properties)
            for name in orderedPropertyNames {
                try nested.encode(properties[name], forKey: PropertyKey(stringValue: name))
            }
        }
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(required, forKey: .required)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
        try container.encodeIfPresent(enumValues, forKey: .enumValues)
        if encodesPropertyOrdering, properties != nil {
            try container.encode(orderedPropertyNames, forKey: .propertyOrdering)
        }
    }

    /// JSON with every object's keys in a fixed order and `properties` in `orderedPropertyNames` order.
    public func orderedJSONString() throws -> String {
        func string(_ value: String) throws -> String {
            String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        }
        var fields: [String] = ["\"type\":\(try string(type))"]
        if let description {
            fields.append("\"description\":\(try string(description))")
        }
        if let enumValues {
            fields.append("\"enum\":[\(try enumValues.map(string).joined(separator: ","))]")
        }
        if let properties {
            let members = try orderedPropertyNames.map { name in
                "\(try string(name)):\(try properties[name]!.orderedJSONString())"
            }
            fields.append("\"properties\":{\(members.joined(separator: ","))}")
        }
        if let items {
            fields.append("\"items\":\(try items.value.orderedJSONString())")
        }
        if let required {
            fields.append("\"required\":[\(try required.map(string).joined(separator: ","))]")
        }
        if let additionalProperties {
            fields.append("\"additionalProperties\":\(additionalProperties)")
        }
        if encodesPropertyOrdering, properties != nil {
            fields.append("\"propertyOrdering\":[\(try orderedPropertyNames.map(string).joined(separator: ","))]")
        }
        return "{\(fields.joined(separator: ","))}"
    }

    /// Converts a Gemini-style schema (uppercase types) to standard JSON Schema:
    /// lowercase types and `additionalProperties: false` on every object, as Claude structured outputs require.
    public func standardized() -> JSONSchema {
        let lowercasedType = type.lowercased()
        return JSONSchema(
            type: lowercasedType,
            properties: properties?.mapValues { $0.standardized() },
            items: items?.value.standardized(),
            required: required,
            description: description,
            additionalProperties: lowercasedType == "object" ? false : additionalProperties,
            enumValues: enumValues,
            propertyOrdering: propertyOrdering,
            encodesPropertyOrdering: false
        )
    }
}

/// Box wrapper to allow recursive JSONSchema (for array items).
public final class JSONSchemaBox: Encodable, @unchecked Sendable {
    public let value: JSONSchema

    public init(_ value: JSONSchema) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

// MARK: - Translation Meta (JSON extraction result)

public struct TranslationMeta: Decodable, Sendable {
    /// Class decided by the model ("word", "expression", "freeText"); `nil` for the on-device model.
    public let textType: String?
    public let normalForm: String?
    public let synonyms: String?
    public let translatedText: String
    public let sourceLanguage: String
    public let shortTranslation: String?
    public let examples: [TranslationExample]?
}

public struct TranslationExample: Codable, Sendable {
    public let original: String
    public let translation: String

    public init(original: String, translation: String) {
        self.original = original
        self.translation = translation
    }
}

// MARK: - Response

public struct GeminiResponse: Decodable, Sendable {
    public let candidates: [Candidate]?

    public struct Candidate: Decodable, Sendable {
        public let content: ContentResponse?
    }

    public struct ContentResponse: Decodable, Sendable {
        public let parts: [PartResponse]?
    }

    public struct PartResponse: Decodable, Sendable {
        public let text: String?
    }

    /// Extract text from first candidate
    public var text: String? {
        candidates?.first?.content?.parts?.compactMap(\.text).joined()
    }
}
