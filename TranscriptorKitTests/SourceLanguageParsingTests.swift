import Testing
@testable import TranscriptorKit

@Suite("TranslationSettings languages")
struct SourceLanguageParsingTests {

    @Test func sourceLanguageForCode() {
        let result = TranslationSettings.sourceLanguage(forCode: "pl")
        #expect(result?.code == "pl")
        #expect(result?.name == "Polish")
    }

    @Test func unknownCodeHasNoSourceLanguage() {
        #expect(TranslationSettings.sourceLanguage(forCode: "tlh") == nil)
        #expect(TranslationSettings.sourceLanguage(forCode: "") == nil)
    }

    // MARK: - Language lists from Locale

    @Test func sourceLanguagesComeFromTheSystem() {
        let codes = TranslationSettings.sourceLanguages.map(\.code)
        #expect(codes.count > 100)
        #expect(Set(codes).count == codes.count)
        #expect(codes.contains("pl") && codes.contains("uk") && codes.contains("zh"))
    }

    @Test func everyTargetLanguageIsASourceLanguage() {
        let codes = Set(TranslationSettings.sourceLanguages.map(\.code))
        #expect(TranslationSettings.supportedLanguages.count == 20)
        for code in TranslationSettings.supportedLanguages {
            #expect(codes.contains(code), "\(code)")
        }
    }

    @Test func targetLanguageNameForThePromptIsEnglish() {
        #expect(TranslationSettings(targetLanguage: "ru").targetLanguageName == "Russian")
        #expect(TranslationSettings.englishName(forCode: "zh") == "Chinese")
    }

    @Test func unknownCodeIsDisplayedAsIs() {
        #expect(TranslationSettings.displayName(forCode: "xx") == "xx")
        #expect(TranslationSettings.englishName(forCode: "xx") == "xx")
    }

    @Test func displayNameIsCapitalized() {
        #expect(TranslationSettings.displayName(forCode: "pl").first?.isUppercase == true)
    }
}
