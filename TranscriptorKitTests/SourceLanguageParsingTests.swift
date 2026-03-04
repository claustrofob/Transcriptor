import Testing
@testable import TranscriptorKit

@Suite("TranslationSettings.sourceLanguage(fromGeminiString:)")
struct SourceLanguageParsingTests {

    // MARK: - Valid inputs

    @Test func polishInRussian() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "Польский (pl)")
        #expect(result?.code == "pl")
        #expect(result?.name == "Polish")
    }

    @Test func englishCode() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "English (en)")
        #expect(result?.code == "en")
    }

    @Test func chineseCode() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "中文 (zh)")
        #expect(result?.code == "zh")
    }

    @Test func codeWithLeadingSpace() {
        // Some LLM responses include a space before the code: "Polish ( pl )"
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "Polish ( pl )")
        // trimCharacters applied — should still resolve
        #expect(result?.code == "pl")
    }

    // MARK: - Multiple parenthesis groups — last pair wins

    @Test func multipleParentheses() {
        // e.g. "Foo (bar) (pl)" — lastIndex picks the last open paren
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "Foo (bar) (pl)")
        #expect(result?.code == "pl")
    }

    // MARK: - Unknown / invalid codes → nil

    @Test func unknownCode() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "Klingon (tlh)")
        #expect(result == nil)
    }

    @Test func noParentheses() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "Polish")
        #expect(result == nil)
    }

    @Test func emptyString() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "")
        #expect(result == nil)
    }

    @Test func emptyParentheses() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "Something ()")
        // Empty code string won't match any language
        #expect(result == nil)
    }

    @Test func onlyOpenParen() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "Polish (")
        #expect(result == nil)
    }

    @Test func onlyCloseParen() {
        let result = TranslationSettings.sourceLanguage(fromGeminiString: "Polish)")
        #expect(result == nil)
    }
}
