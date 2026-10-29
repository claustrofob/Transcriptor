import Foundation
import Testing
@testable import TranscriptorKit

@Suite("PromptBuilder")
struct PromptBuilderTests {

    // MARK: - Classification (cloud prompt)

    @Test func cloudPromptAsksToClassifyFirst() {
        let prompt = makePrompt()
        #expect(prompt.contains("CLASSIFY THE INPUT"))
        #expect(prompt.contains("\"textType\""))
    }

    @Test func cloudPromptListsEveryTextType() {
        let prompt = makePrompt()
        for type in TranslationType.allCases {
            #expect(prompt.contains("\"\(type.rawValue)\""))
        }
    }

    @Test func cloudPromptHasDictionaryFormatForWords() {
        let prompt = makePrompt()
        #expect(prompt.contains("5-8 examples"))
        #expect(prompt.contains("Numbered list"))
    }

    @Test func cloudPromptEmptiesDictionaryFieldsForFreeText() {
        let prompt = makePrompt()
        #expect(prompt.contains("\"examples\" → empty array"))
    }

    // MARK: - Plain prompt (on-device)

    @Test func plainPromptDoesNotClassify() {
        let prompt = makePlainPrompt()
        #expect(prompt.contains("Translate the given text"))
        #expect(!prompt.contains("textType"))
        #expect(!prompt.contains("examples"))
    }

    // MARK: - Target language injection

    @Test func targetLanguageAppearsInPrompt() {
        #expect(makePrompt(language: "Spanish").contains("Spanish"))
    }

    @Test func plainTargetLanguageAppearsInPrompt() {
        #expect(makePlainPrompt(language: "German").contains("German"))
    }

    // MARK: - Source language override

    @Test func noOverrideWhenNil() {
        #expect(!makePrompt(sourceOverride: nil).contains("SOURCE LANGUAGE OVERRIDE"))
    }

    @Test func overridePrependedWhenProvided() {
        #expect(makePrompt(sourceOverride: "Polish").hasPrefix("SOURCE LANGUAGE OVERRIDE"))
        #expect(makePlainPrompt(sourceOverride: "Polish").hasPrefix("SOURCE LANGUAGE OVERRIDE"))
    }

    @Test func overrideContainsLanguageName() {
        #expect(makePrompt(sourceOverride: "Polish").contains("Polish"))
    }

    @Test func overrideAppearsExactlyOnce() {
        let prompt = makePrompt(sourceOverride: "Polish")
        let count = prompt.components(separatedBy: "SOURCE LANGUAGE OVERRIDE").count - 1
        #expect(count == 1)
    }

    // MARK: - No markdown rule present

    @Test func noMarkdownRuleInBothPrompts() {
        #expect(makePrompt().contains("No Markdown"))
        #expect(makePlainPrompt().contains("No Markdown"))
    }

    // MARK: - Helpers

    private func makePrompt(language: String = "Russian", sourceOverride: String? = nil) -> String {
        PromptBuilder.translationPrompt(for: TranslationSettings(targetLanguage: language), sourceLanguageOverride: sourceOverride)
    }

    private func makePlainPrompt(language: String = "Russian", sourceOverride: String? = nil) -> String {
        PromptBuilder.plainTranslationPrompt(for: TranslationSettings(targetLanguage: language), sourceLanguageOverride: sourceOverride)
    }
}

@Suite("TranslationSchema")
struct TranslationSchemaTests {

    @Test func textTypeIsRequiredEnumOfAllTypes() throws {
        let schema = TranslationSchema.schema(lang: "Russian")
        #expect(schema.required?.contains("textType") == true)
        let textType = try #require(schema.properties?["textType"])
        #expect(textType.enumValues == TranslationType.allCases.map(\.rawValue))
    }

    @Test func enumIsEncodedUnderEnumKey() throws {
        let data = try JSONEncoder().encode(TranslationSchema.schema(lang: "Russian").standardized())
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"enum\""))
        #expect(!json.contains("enumValues"))
    }
}

@Suite("TranslationHelper.textType")
struct TextTypeParsingTests {

    @Test func usesClassReportedByModel() throws {
        #expect(TranslationHelper.textType(of: try meta(#"{"textType":"expression","normalForm":"","translatedText":"t","sourceLanguage":"en"}"#)) == .expression)
        #expect(TranslationHelper.textType(of: try meta(#"{"textType":"freeText","normalForm":"x","translatedText":"t","sourceLanguage":"en"}"#)) == .freeText)
    }

    @Test func missingClassWithoutDictionaryFieldsIsFreeText() throws {
        #expect(TranslationHelper.textType(of: try meta(#"{"translatedText":"t","sourceLanguage":"en"}"#)) == .freeText)
    }

    @Test func unknownClassWithDictionaryFieldsIsWord() throws {
        #expect(TranslationHelper.textType(of: try meta(#"{"textType":"sentence","normalForm":"dog","translatedText":"t","sourceLanguage":"en"}"#)) == .word)
    }

    private func meta(_ json: String) throws -> TranslationMeta {
        try JSONDecoder().decode(TranslationMeta.self, from: Data(json.utf8))
    }
}
