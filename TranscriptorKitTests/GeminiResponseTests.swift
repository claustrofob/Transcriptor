import Testing
import Foundation
@testable import TranscriptorKit

@Suite("GeminiResponse.text")
struct GeminiResponseTests {

    // MARK: - Text extraction

    @Test func extractsTextFromSinglePart() {
        let response = makeResponse(parts: ["Hello world"])
        #expect(response.text == "Hello world")
    }

    @Test func concatenatesMultipleParts() {
        let response = makeResponse(parts: ["Hello", " ", "world"])
        #expect(response.text == "Hello world")
    }

    @Test func nilWhenNoCandidates() {
        let response = GeminiResponse(candidates: nil)
        #expect(response.text == nil)
    }

    @Test func nilWhenEmptyCandidates() {
        let response = GeminiResponse(candidates: [])
        #expect(response.text == nil)
    }

    @Test func nilWhenCandidateHasNoContent() {
        let candidate = GeminiResponse.Candidate(content: nil)
        let response = GeminiResponse(candidates: [candidate])
        #expect(response.text == nil)
    }

    @Test func nilWhenContentHasNoParts() {
        let content = GeminiResponse.ContentResponse(parts: nil)
        let candidate = GeminiResponse.Candidate(content: content)
        let response = GeminiResponse(candidates: [candidate])
        #expect(response.text == nil)
    }

    @Test func emptyStringWhenPartsHaveNilText() {
        // compactMap filters nil texts → [], joined() → ""; result is "" not nil
        let parts = [GeminiResponse.PartResponse(text: nil)]
        let content = GeminiResponse.ContentResponse(parts: parts)
        let candidate = GeminiResponse.Candidate(content: content)
        let response = GeminiResponse(candidates: [candidate])
        #expect(response.text == "")
    }

    @Test func usesFirstCandidateOnly() {
        let first = makeCandidate(text: "first")
        let second = makeCandidate(text: "second")
        let response = GeminiResponse(candidates: [first, second])
        #expect(response.text == "first")
    }

    // MARK: - JSON round-trip decoding

    @Test func decodesFromJSON() throws {
        let json = """
        {
            "candidates": [{
                "content": {
                    "parts": [{ "text": "decoded text" }],
                    "role": "model"
                },
                "finishReason": "STOP"
            }]
        }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        #expect(response.text == "decoded text")
    }

    @Test func decodesErrorResponse() throws {
        let json = """
        {
            "error": {
                "code": 403,
                "message": "API key not valid.",
                "status": "PERMISSION_DENIED"
            }
        }
        """
        let error = try JSONDecoder().decode(APIErrorResponse.self, from: Data(json.utf8))
        #expect(error.error.message == "API key not valid.")
    }

    // MARK: - Helpers

    private func makeResponse(parts: [String]) -> GeminiResponse {
        GeminiResponse(candidates: [makeCandidate(parts: parts)])
    }

    private func makeCandidate(text: String) -> GeminiResponse.Candidate {
        makeCandidate(parts: [text])
    }

    private func makeCandidate(parts: [String]) -> GeminiResponse.Candidate {
        let responseParts = parts.map { GeminiResponse.PartResponse(text: $0) }
        let content = GeminiResponse.ContentResponse(parts: responseParts)
        return GeminiResponse.Candidate(content: content)
    }
}
