import Testing
@testable import TranscriptorKit

@Suite("PromptBuilder.translationPrompt")
struct PromptBuilderTests {

    // MARK: - Translation type routing

    @Test func wordTypeProducesWordInstructions() {
        let prompt = makePrompt(type: .word)
        #expect(prompt.contains("words and phrases"))
        #expect(!prompt.contains("expressions and idioms"))
        #expect(!prompt.contains("Translate the given text"))
    }

    @Test func expressionTypeProducesExpressionInstructions() {
        let prompt = makePrompt(type: .expression)
        #expect(prompt.contains("expressions and idioms"))
        #expect(!prompt.contains("words and phrases"))
        #expect(!prompt.contains("Translate the given text"))
    }

    @Test func freeTextTypeProducesFreeTextInstructions() {
        let prompt = makePrompt(type: .freeText)
        #expect(prompt.contains("Translate the given text"))
        #expect(!prompt.contains("words and phrases"))
        #expect(!prompt.contains("expressions and idioms"))
    }

    // MARK: - Target language injection

    @Test func targetLanguageAppearsInPrompt() {
        let prompt = makePrompt(type: .word, language: "Spanish")
        #expect(prompt.contains("Spanish"))
    }

    @Test func freeTextTargetLanguageAppearsInPrompt() {
        let prompt = makePrompt(type: .freeText, language: "German")
        #expect(prompt.contains("German"))
    }

    // MARK: - Source language override

    @Test func noOverrideWhenNil() {
        let prompt = makePrompt(type: .word, sourceOverride: nil)
        #expect(!prompt.contains("SOURCE LANGUAGE OVERRIDE"))
    }

    @Test func overridePrependedWhenProvided() {
        let prompt = makePrompt(type: .word, sourceOverride: "Polish")
        #expect(prompt.hasPrefix("SOURCE LANGUAGE OVERRIDE"))
    }

    @Test func overrideContainsLanguageName() {
        let prompt = makePrompt(type: .word, sourceOverride: "Polish")
        #expect(prompt.contains("Polish"))
    }

    @Test func overrideAppearsExactlyOnce() {
        let prompt = makePrompt(type: .word, sourceOverride: "Polish")
        let count = prompt.components(separatedBy: "SOURCE LANGUAGE OVERRIDE").count - 1
        #expect(count == 1)
    }

    // MARK: - Result format (always detailed)

    @Test func wordPromptHasFiveToEightExamples() {
        let prompt = makePrompt(type: .word)
        #expect(prompt.contains("5-8 examples"))
    }

    @Test func wordPromptHasNumberedList() {
        let prompt = makePrompt(type: .word)
        #expect(prompt.contains("Numbered list"))
    }

    // MARK: - No markdown rule present

    @Test func noMarkdownRuleInWordPrompt() {
        let prompt = makePrompt(type: .word)
        #expect(prompt.contains("No Markdown"))
    }

    @Test func noMarkdownRuleInFreeTextPrompt() {
        let prompt = makePrompt(type: .freeText)
        #expect(prompt.contains("No Markdown"))
    }

    // MARK: - Helpers

    private func makePrompt(
        type: TranslationType,
        language: String = "Russian",
        sourceOverride: String? = nil
    ) -> String {
        let settings = TranslationSettings(
            targetLanguage: language
        )
        return PromptBuilder.translationPrompt(
            for: settings,
            translationType: type,
            sourceLanguageOverride: sourceOverride
        )
    }
}
