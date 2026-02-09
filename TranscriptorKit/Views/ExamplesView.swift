import SwiftUI

/// A view that renders translation examples as a formatted list.
public struct ExamplesView: View {

    private let examples: [TranslationExample]
    private let header: String

    /// - Parameters:
    ///   - examples: Array of translation examples.
    ///   - header: Section header (e.g. "Примеры", "Examples").
    public init(_ examples: [TranslationExample], header: String = "Examples") {
        self.examples = examples
        self.header = header
    }

    public var body: some View {
        if !examples.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(header)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(example.original)
                                    .font(.body)
                                Text(example.translation)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .textSelection(.enabled)
        }
    }
}
