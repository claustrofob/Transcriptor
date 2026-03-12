import Testing
@testable import TranscriptorKit

@Suite("String.strippingMarkdown")
struct StringMarkdownTests {

    @Test func doubleAsteriskBold() {
        #expect("**bold**".strippingMarkdown == "bold")
    }

    @Test func doubleUnderscoreBold() {
        #expect("__bold__".strippingMarkdown == "bold")
    }

    @Test func singleAsteriskItalic() {
        #expect("*italic*".strippingMarkdown == "italic")
    }

    @Test func singleUnderscoreItalic() {
        #expect("_italic_".strippingMarkdown == "italic")
    }

    @Test func mixedMarkdown() {
        #expect("**bold** and _italic_".strippingMarkdown == "bold and italic")
    }

    @Test func noMarkdown() {
        let plain = "plain text without formatting"
        #expect(plain.strippingMarkdown == plain)
    }

    @Test func emptyString() {
        #expect("".strippingMarkdown == "")
    }

    @Test func nestedMarkers() {
        #expect("**__nested__**".strippingMarkdown == "nested")
    }

    @Test func onlyMarkers() {
        #expect("****".strippingMarkdown == "")
    }
}
