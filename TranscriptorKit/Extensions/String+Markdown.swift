import Foundation

extension String {
    /// Strips basic Markdown formatting (bold, italic) from a string.
    public var strippingMarkdown: String {
        self.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
