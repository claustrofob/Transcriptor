import Testing
@testable import TranscriptorKit

@Suite("TextClassifier")
struct TextClassifierTests {

    // MARK: - Word (≤ 2 tokens)

    @Test func singleWord() {
        let result = TextClassifier.classify("podekscytowany")
        #expect(result == .word)
    }

    // The on-device model used to classify these as free text.
    @Test func shortInputsMisclassifiedByTheModelAreWords() {
        #expect(TextClassifier.classify("Cześć") == .word)
        #expect(TextClassifier.classify("Cześć!") == .word)
        #expect(TextClassifier.classify("Nie możesz") == .word)
    }

    @Test func twoWords() {
        let result = TextClassifier.classify("das Haus")
        #expect(result == .word)
    }

    @Test func emptyString() {
        let result = TextClassifier.classify("")
        #expect(result == .word)
    }

    @Test func whitespaceOnly() {
        let result = TextClassifier.classify("   ")
        #expect(result == .word)
    }

    // MARK: - Expression (3–5 tokens, no sentence punctuation)

    @Test func threeWordExpression() {
        let result = TextClassifier.classify("break the ice")
        #expect(result == .expression)
    }

    @Test func fiveWordExpression() {
        let result = TextClassifier.classify("в конце концов всё таки")
        #expect(result == .expression)
    }

    @Test func fourWordExpressionWithoutPunctuation() {
        let result = TextClassifier.classify("coûte que coûte vraiment")
        #expect(result == .expression)
    }

    // MARK: - Expression edge: punctuation forces freeText

    @Test func threeWordsWithPeriod() {
        let result = TextClassifier.classify("He ran fast.")
        #expect(result == .freeText)
    }

    @Test func threeWordsWithQuestion() {
        let result = TextClassifier.classify("How are you?")
        #expect(result == .freeText)
    }

    @Test func threeWordsWithExclamation() {
        let result = TextClassifier.classify("Stop it now!")
        #expect(result == .freeText)
    }

    @Test func threeWordsWithSemicolon() {
        let result = TextClassifier.classify("one two; three")
        #expect(result == .freeText)
    }

    @Test func threeWordsWithColon() {
        let result = TextClassifier.classify("items: one two")
        #expect(result == .freeText)
    }

    // MARK: - FreeText (6+ tokens)

    @Test func sixWordsNoPunctuation() {
        let result = TextClassifier.classify("one two three four five six")
        #expect(result == .freeText)
    }

    @Test func fullSentence() {
        let result = TextClassifier.classify("Jestem podekscytowany tą wspaniałą wiadomością.")
        #expect(result == .freeText)
    }

    @Test func longParagraph() {
        let text = "The quick brown fox jumps over the lazy dog and then runs away quickly."
        let result = TextClassifier.classify(text)
        #expect(result == .freeText)
    }
}
