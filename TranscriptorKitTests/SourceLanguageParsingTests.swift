import Testing
@testable import TranscriptorKit

@Suite("TranslationSettings.sourceLanguage(fromModelString:)")
struct SourceLanguageParsingTests {

    // MARK: - ISO code (current format)

    @Test func plainCode() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "pl")
        #expect(result?.code == "pl")
        #expect(result?.name == "Polish")
    }

    @Test func plainCodeIsTrimmedAndLowercased() {
        #expect(TranslationSettings.sourceLanguage(fromModelString: " PL ")?.code == "pl")
    }

    @Test func unknownPlainCode() {
        #expect(TranslationSettings.sourceLanguage(fromModelString: "tlh") == nil)
    }

    // MARK: - Legacy "Name (code)" format

    @Test func polishInRussian() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "Польский (pl)")
        #expect(result?.code == "pl")
        #expect(result?.name == "Polish")
    }

    @Test func englishCode() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "English (en)")
        #expect(result?.code == "en")
    }

    @Test func chineseCode() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "中文 (zh)")
        #expect(result?.code == "zh")
    }

    @Test func codeWithLeadingSpace() {
        // Some LLM responses include a space before the code: "Polish ( pl )"
        let result = TranslationSettings.sourceLanguage(fromModelString: "Polish ( pl )")
        // trimCharacters applied — should still resolve
        #expect(result?.code == "pl")
    }

    // MARK: - Multiple parenthesis groups — last pair wins

    @Test func multipleParentheses() {
        // e.g. "Foo (bar) (pl)" — lastIndex picks the last open paren
        let result = TranslationSettings.sourceLanguage(fromModelString: "Foo (bar) (pl)")
        #expect(result?.code == "pl")
    }

    // MARK: - Unknown / invalid codes → nil

    @Test func unknownCode() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "Klingon (tlh)")
        #expect(result == nil)
    }

    @Test func noParentheses() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "Polish")
        #expect(result == nil)
    }

    @Test func emptyString() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "")
        #expect(result == nil)
    }

    @Test func emptyParentheses() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "Something ()")
        // Empty code string won't match any language
        #expect(result == nil)
    }

    @Test func onlyOpenParen() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "Polish (")
        #expect(result == nil)
    }

    @Test func onlyCloseParen() {
        let result = TranslationSettings.sourceLanguage(fromModelString: "Polish)")
        #expect(result == nil)
    }

    // MARK: - Display name

    @Test func nameForKnownCode() {
        #expect(TranslationSettings.languageName(fromModelString: "pl") == "Polish")
    }

    @Test func nameForLegacyFormat() {
        #expect(TranslationSettings.languageName(fromModelString: "Польский (pl)") == "Polish")
    }

    @Test func nameForCodeOutsideTheListComesFromLocale() {
        // Latin isn't in `sourceLanguages`, but the system knows the code.
        #expect(TranslationSettings.languageName(fromModelString: "la") == "Latin")
    }
}
