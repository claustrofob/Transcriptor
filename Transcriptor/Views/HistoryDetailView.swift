import SwiftUI
import TranscriptorKit

struct HistoryDetailView: View {
    let result: TranslationResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Original text
                GroupBox {
                    Text(result.sourceText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Original", systemImage: "text.quote")
                }

                // Translation + examples + copy button
                TranslationContentView(result: result)

                // Metadata
                HStack {
                    if let sourceLanguage = result.sourceLanguage {
                        Label(sourceLanguage, systemImage: "textformat")
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                    }
                    Label(result.targetLanguage, systemImage: "globe")
                    Spacer()
                    Label(result.model, systemImage: "cpu")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(result.createdAt, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .navigationTitle("Translation")
        .navigationBarTitleDisplayMode(.inline)
    }
}
