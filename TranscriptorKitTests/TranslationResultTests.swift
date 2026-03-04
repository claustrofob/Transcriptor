import Testing
import Foundation
@testable import TranscriptorKit

@Suite("TranslationResult")
struct TranslationResultTests {

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

    @Test func classifiedTypeWordRoundTrip() {
        let result = makeResult()
        result.classifiedType = .word
        #expect(result.translationType == "word")
        #expect(result.classifiedType == .word)
    }

    @Test func classifiedTypeExpressionRoundTrip() {
        let result = makeResult()
        result.classifiedType = .expression
        #expect(result.translationType == "expression")
        #expect(result.classifiedType == .expression)
    }

    @Test func classifiedTypeFreeTextRoundTrip() {
        let result = makeResult()
        result.classifiedType = .freeText
        #expect(result.translationType == "freeText")
        #expect(result.classifiedType == .freeText)
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
            targetLanguage: "Russian",
            model: "gemini-2.5-flash"
        )
    }
}
