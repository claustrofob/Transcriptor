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
                    TranslationContentView(result: result)
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

                HStack {
                    Text(result.createdAt, format: .dateTime)
                    Spacer()
                    if let duration = result.responseDuration {
                        Label(
                            Duration.seconds(duration).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))),
                            systemImage: "timer"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .navigationTitle("Translation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                CopyTranslationButton(result.translatedText)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(result: TranslationResult(
            sourceText: "podekscytowany",
            translatedText: "прилагательное (м.р.)\nвзволнованный, возбуждённый",
            normalForm: "podekscytowany",
            shortTranslation: "взволнованный, возбуждённый",
            sourceLanguage: "Польский (pl)",
            targetLanguage: "Russian",
            model: "claude-opus-5-5",
            responseDuration: 2.37
        ))
    }
}
