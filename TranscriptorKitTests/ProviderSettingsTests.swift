import Testing
import Foundation
@testable import TranscriptorKit

@Suite("TranslationSettings providers")
struct ProviderSettingsTests {

    // MARK: - Decoding

    @Test func decodesLegacySettingsAsGoogle() throws {
        let json = #"{"targetLanguage":"pl","detailLevel":"detailed","model":"gemini-2.5-pro"}"#
        let settings = try JSONDecoder().decode(TranslationSettings.self, from: Data(json.utf8))
        #expect(settings.provider == .google)
        #expect(settings.geminiModel == .gemini35FlashLite)
        #expect(settings.claudeModel == TranslationSettings.default.claudeModel)
        #expect(settings.targetLanguage == "pl")
    }

    @Test(arguments: [
        ("gemini-2.5-flash", TranslationSettings.GeminiModel.gemini35FlashLite),
        ("gemini-2.5-pro", .gemini35FlashLite),
        ("gemini-3.8-flash", .gemini38Flash),
        ("gemini-4-argon", .gemini4Argon),
    ])
    func retiredGeminiModelsMoveToReplacements(stored: String, expected: TranslationSettings.GeminiModel) throws {
        let json = #"{"targetLanguage":"ru","model":"\#(stored)"}"#
        let settings = try JSONDecoder().decode(TranslationSettings.self, from: Data(json.utf8))
        #expect(settings.geminiModel == expected)
    }

    @Test func roundTripKeepsBothProviderModels() throws {
        let original = TranslationSettings(
            targetLanguage: "de",
            provider: .anthropic,
            geminiModel: .gemini35FlashLite,
            claudeModel: .haiku55
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranslationSettings.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Switching

    @Test func switchingProviderKeepsOtherModel() {
        var settings = TranslationSettings(targetLanguage: "ru", geminiModel: .gemini4Argon)
        settings.provider = .anthropic
        settings.claudeModel = .sonnet55
        settings.provider = .google
        #expect(settings.geminiModel == .gemini4Argon)
        #expect(settings.claudeModel == .sonnet55)
    }

    @Test func modelIDFollowsActiveProvider() {
        var settings = TranslationSettings(targetLanguage: "ru", geminiModel: .gemini38Flash, claudeModel: .opus55)
        #expect(settings.modelID == "gemini-3.8-flash")
        settings.provider = .anthropic
        #expect(settings.modelID == "claude-opus-5-5")
    }

    // MARK: - On-device provider

    @Test func onDeviceProviderRoundTrips() throws {
        let original = TranslationSettings(targetLanguage: "ru", provider: .apple)
        let decoded = try JSONDecoder().decode(TranslationSettings.self, from: JSONEncoder().encode(original))
        #expect(decoded.provider == .apple)
    }

    @Test func onDeviceProviderNeedsNoKeyAndHasFixedModelID() {
        let settings = TranslationSettings(targetLanguage: "ru", provider: .apple)
        #expect(!settings.provider.requiresAPIKey)
        #expect(TranslationSettings.Provider.google.requiresAPIKey)
        #expect(TranslationSettings.Provider.anthropic.requiresAPIKey)
        #expect(settings.modelID == "apple-on-device")
    }

    // MARK: - Fallbacks

    @Test func serverFallbackSkippedOnlyForHaiku() {
        #expect(TranslationSettings.ClaudeModel.opus55.supportsServerFallback)
        #expect(TranslationSettings.ClaudeModel.sonnet55.supportsServerFallback)
        #expect(!TranslationSettings.ClaudeModel.haiku55.supportsServerFallback)
    }
}

@Suite("JSONSchema.standardized")
struct JSONSchemaStandardizedTests {

    @Test func lowercasesTypesAndClosesObjects() throws {
        let schema = TranslationSchema.schema(lang: "Russian").standardized()
        let object = try encodedObject(schema)

        #expect(object["type"] as? String == "object")
        #expect(object["additionalProperties"] as? Bool == false)

        let properties = try #require(object["properties"] as? [String: Any])
        let normalForm = try #require(properties["normalForm"] as? [String: Any])
        #expect(normalForm["type"] as? String == "string")
        #expect(normalForm["additionalProperties"] == nil)

        let examples = try #require(properties["examples"] as? [String: Any])
        #expect(examples["type"] as? String == "array")
        let items = try #require(examples["items"] as? [String: Any])
        #expect(items["type"] as? String == "object")
        #expect(items["additionalProperties"] as? Bool == false)
    }

    @Test func geminiSchemaHasNoAdditionalProperties() throws {
        let object = try encodedObject(TranslationSchema.schema(lang: "Russian"))
        #expect(object["type"] as? String == "OBJECT")
        #expect(object["additionalProperties"] == nil)
    }

    private func encodedObject(_ schema: JSONSchema) throws -> [String: Any] {
        let data = try JSONEncoder().encode(schema)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

@Suite("Claude API models")
struct ClaudeModelsTests {

    @Test func responseTextSkipsNonTextBlocks() throws {
        let json = #"""
        {"content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"a\":"},{"type":"text","text":"1}"}],
         "stop_reason":"end_turn","stop_details":null}
        """#
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: Data(json.utf8))
        #expect(response.text == #"{"a":1}"#)
        #expect(response.stopReason == "end_turn")
    }

    @Test func decodesRefusalDetails() throws {
        let json = #"{"content":[],"stop_reason":"refusal","stop_details":{"type":"refusal","category":"cyber","explanation":"Not allowed"}}"#
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: Data(json.utf8))
        #expect(response.stopReason == "refusal")
        #expect(response.stopDetails?.explanation == "Not allowed")
        #expect(response.text.isEmpty)
    }

    @Test func requestUsesSnakeCaseWireNames() throws {
        let request = ClaudeRequest(
            model: "claude-opus-5-5",
            maxTokens: 16000,
            systemPrompt: "system",
            userText: "hello",
            effort: "medium",
            schema: JSONSchema(type: "object", additionalProperties: false),
            fallbacks: "default"
        )
        let data = try JSONEncoder().encode(request)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["max_tokens"] as? Int == 16000)
        #expect(object["fallbacks"] as? String == "default")
        let outputConfig = try #require(object["output_config"] as? [String: Any])
        #expect(outputConfig["effort"] as? String == "medium")
        let format = try #require(outputConfig["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let messages = try #require(object["messages"] as? [[String: Any]])
        #expect(messages.first?["role"] as? String == "user")
        #expect(messages.first?["content"] as? String == "hello")
    }

    @Test func requestOmitsFallbacksWhenNil() throws {
        let request = ClaudeRequest(
            model: "claude-haiku-5-5",
            maxTokens: 16000,
            systemPrompt: "system",
            userText: "hello",
            effort: "medium",
            schema: JSONSchema(type: "object", additionalProperties: false),
            fallbacks: nil
        )
        let data = try JSONEncoder().encode(request)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["fallbacks"] == nil)
    }
}

@Suite("TranslationHelper.fallbackReason")
struct FallbackReasonTests {

    @Test func missingAPIKeyFallsBack() {
        let reason = TranslationHelper.fallbackReason(for: TranslationError.noAPIKey(provider: .anthropic), provider: .anthropic)
        #expect(reason == .noAPIKey(.anthropic))
    }

    @Test func noConnectionFallsBack() {
        #expect(TranslationHelper.fallbackReason(for: URLError(.notConnectedToInternet), provider: .google) == .network)
        #expect(TranslationHelper.fallbackReason(for: URLError(.timedOut), provider: .google) == .network)
    }

    @Test func cancellationDoesNotFallBack() {
        #expect(TranslationHelper.fallbackReason(for: URLError(.cancelled), provider: .google) == nil)
        #expect(TranslationHelper.fallbackReason(for: CancellationError(), provider: .google) == nil)
    }

    @Test func apiErrorsDoNotFallBack() {
        let error = TranslationError.apiError(statusCode: 401, message: "invalid key")
        #expect(TranslationHelper.fallbackReason(for: error, provider: .anthropic) == nil)
    }

    @Test func onDeviceProviderNeverFallsBack() {
        #expect(TranslationHelper.fallbackReason(for: URLError(.notConnectedToInternet), provider: .apple) == nil)
    }
}
