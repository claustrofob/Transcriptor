import SwiftUI

/// A view that renders translation examples as a formatted list.
public struct ExamplesView: View {

    private let examples: [TranslationExample]

    public init(_ examples: [TranslationExample]) {
        self.examples = examples
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(examples.enumerated(), id: \.offset) { _, example in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.original)
                        Text(example.translation)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .textSelection(.enabled)
    }
}
