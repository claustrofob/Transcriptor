import Testing
import Foundation
@testable import TranscriptorKit

@Suite("TranslationResult")
struct TranslationResultTests {

    // MARK: - display names

    @Test func sourceLanguageDisplayNameFromCode() {
        let result = makeResult()
        result.sourceLanguage = "pl"
        #expect(result.sourceLanguageDisplayName == TranslationSettings.displayName(forCode: "pl"))
    }

    @Test func sourceLanguageDisplayNameIsNilWhenNotDetected() {
        #expect(makeResult().sourceLanguageDisplayName == nil)
    }

    // MARK: - responseDuration

    @Test func responseDurationDefaultsToNil() {
        #expect(makeResult().responseDuration == nil)
    }

    @Test func responseDurationIsStored() {
        let result = TranslationResult(sourceText: "a", translatedText: "b", targetLanguage: "ru", model: "m", responseDuration: 1.25)
        #expect(result.responseDuration == 1.25)
    }

    // MARK: - examples encode / decode

    @Test func examplesRoundTrip() {
        let result = makeResult()
        let examples = [
            TranslationExample(original: "Jestem podekscytowany.", translation: "Я взволнован."),
            TranslationExample(original: "To jest piękny dzień.", translation: "Это прекрасный день.")
        ]
        result.examples = examples
        let loaded = result.examples
        #expect(loaded.count == 2)
        #expect(loaded[0].original == "Jestem podekscytowany.")
        #expect(loaded[0].translation == "Я взволнован.")
        #expect(loaded[1].original == "To jest piękny dzień.")
    }

    @Test func emptyExamplesRoundTrip() {
        let result = makeResult()
        result.examples = []
        #expect(result.examples.isEmpty)
    }

    @Test func nilExamplesDataReturnsEmptyArray() {
        let result = makeResult()
        result.examplesData = nil
        #expect(result.examples.isEmpty)
    }

    @Test func corruptExamplesDataReturnsEmptyArray() {
        let result = makeResult()
        result.examplesData = Data("not json".utf8)
        #expect(result.examples.isEmpty)
    }

    // MARK: - classifiedType

    @Test func classifiedTypeDefaultsToWordForNilRawValue() {
        let result = makeResult()
        result.translationType = nil
        #expect(result.classifiedType == .word)
    }

    @Test(arguments: TranslationType.allCases)
    func classifiedTypeIsStored(type: TranslationType) {
        let result = TranslationResult(sourceText: "a", translatedText: "b", targetLanguage: "ru", model: "m", translationType: type)
        #expect(result.translationType == type.rawValue)
        #expect(result.classifiedType == type)
    }

    @Test func unknownRawValueDefaultsToWord() {
        let result = makeResult()
        result.translationType = "unknownValue"
        #expect(result.classifiedType == .word)
    }

    // MARK: - Helpers

    private func makeResult() -> TranslationResult {
        TranslationResult(
            sourceText: "podekscytowany",
            translatedText: "взволнованный",
            targetLanguage: "ru",
            model: "gemini-3.8-flash"
        )
    }
}

@Suite("TranslationContentView.copyText")
@MainActor
struct CopyTextTests {

    @Test func includesEveryBlockInDisplayOrder() {
        let view = TranslationContentView(
            normalForm: "podekscytowany",
            synonyms: "podniecony, ożywiony",
            translatedText: "прилагательное\nвзволнованный",
            examples: [
                TranslationExample(original: "Jestem podekscytowany.", translation: "Я взволнован."),
                TranslationExample(original: "Był podekscytowany.", translation: "Он был взволнован."),
            ]
        )
        #expect(view.copyText == """
            podekscytowany
            podniecony, ożywiony

            прилагательное
            взволнованный

            • Jestem podekscytowany. — Я взволнован.
            • Był podekscytowany. — Он был взволнован.
            """)
    }

    @Test func freeTextIsJustTheTranslation() {
        let view = TranslationContentView(normalForm: "", synonyms: nil, translatedText: "Доброе утро")
        #expect(view.copyText == "Доброе утро")
    }
}
