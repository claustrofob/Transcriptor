import SwiftUI

/// Capsule badge for displaying a language label.
public struct LanguageBadge: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.fill.tertiary)
            .clipShape(Capsule())
    }
}
