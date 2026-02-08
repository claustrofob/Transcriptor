import SwiftUI
import TranscriptorKit

struct HistoryDetailView: View {
    let result: TranslationResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    Text(result.sourceText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Original", systemImage: "text.quote")
                }

                GroupBox {
                    Text(result.translatedText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Translation", systemImage: "text.bubble")
                }

                HStack {
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIPasteboard.general.string = result.translatedText
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }
}
