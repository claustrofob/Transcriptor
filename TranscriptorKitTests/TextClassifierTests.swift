import Testing
@testable import TranscriptorKit

@Suite("TextClassifier — heuristic fallback")
struct TextClassifierTests {

    // MARK: - Word (≤ 2 tokens)

    @Test func singleWord() async {
        let result = await TextClassifier.classify("podekscytowany")
        #expect(result == .word)
    }

    @Test func twoWords() async {
        let result = await TextClassifier.classify("das Haus")
        #expect(result == .word)
    }

    @Test func emptyString() async {
        let result = await TextClassifier.classify("")
        #expect(result == .word)
    }

    @Test func whitespaceOnly() async {
        let result = await TextClassifier.classify("   ")
        #expect(result == .word)
    }

    // MARK: - Expression (3–5 tokens, no sentence punctuation)

    @Test func threeWordExpression() async {
        let result = await TextClassifier.classify("break the ice")
        #expect(result == .expression)
    }

    @Test func fiveWordExpression() async {
        let result = await TextClassifier.classify("в конце концов всё таки")
        #expect(result == .expression)
    }

    @Test func fourWordExpressionWithoutPunctuation() async {
        let result = await TextClassifier.classify("coûte que coûte vraiment")
        #expect(result == .expression)
    }

    // MARK: - Expression edge: punctuation forces freeText

    @Test func threeWordsWithPeriod() async {
        let result = await TextClassifier.classify("He ran fast.")
        #expect(result == .freeText)
    }

    @Test func threeWordsWithQuestion() async {
        let result = await TextClassifier.classify("How are you?")
        #expect(result == .freeText)
    }

    @Test func threeWordsWithExclamation() async {
        let result = await TextClassifier.classify("Stop it now!")
        #expect(result == .freeText)
    }

    @Test func threeWordsWithSemicolon() async {
        let result = await TextClassifier.classify("one two; three")
        #expect(result == .freeText)
    }

    @Test func threeWordsWithColon() async {
        let result = await TextClassifier.classify("items: one two")
        #expect(result == .freeText)
    }

    // MARK: - FreeText (6+ tokens)

    @Test func sixWordsNoPunctuation() async {
        let result = await TextClassifier.classify("one two three four five six")
        #expect(result == .freeText)
    }

    @Test func fullSentence() async {
        let result = await TextClassifier.classify("Jestem podekscytowany tą wspaniałą wiadomością.")
        #expect(result == .freeText)
    }

    @Test func longParagraph() async {
        let text = "The quick brown fox jumps over the lazy dog and then runs away quickly."
        let result = await TextClassifier.classify(text)
        #expect(result == .freeText)
    }
}
