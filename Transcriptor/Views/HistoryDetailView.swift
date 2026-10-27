import SwiftUI
import TranscriptorKit

struct HistoryDetailView: View {
    let result: TranslationResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OriginalTextBox(result.sourceText)

                // Read-only counterpart of the language bar on the Translate screen.
                LanguagePair {
                    Text(sourceLanguageName)
                } target: {
                    Text(result.targetLanguage)
                }
                .font(.subheadline)
                .lineLimit(1)
                .padding(.vertical, 7)

                TranslationBox {
                    // Source language is shown in the language pair instead of a badge.
                    TranslationContentView(
                        normalForm: result.normalForm,
                        synonyms: result.synonyms,
                        translatedText: result.translatedText,
                        sourceLanguage: nil,
                        examples: result.examples
                    )
                }

                HStack {
                    Label(result.model, systemImage: "cpu")
                    Spacer()
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

    private var sourceLanguageName: String {
        guard let raw = result.sourceLanguage else { return "Unknown" }
        return TranslationSettings.sourceLanguage(fromGeminiString: raw)?.name ?? raw
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
