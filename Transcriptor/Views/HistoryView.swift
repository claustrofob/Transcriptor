import SwiftUI
import SwiftData
import TranscriptorKit

struct HistoryView: View {
    @Query(sort: \TranslationResult.createdAt, order: .reverse)
    private var allTranslations: [TranslationResult]

    @Environment(\.modelContext) private var modelContext

    private var translations: [TranslationResult] {
        Array(allTranslations.prefix(50))
    }

    var body: some View {
        NavigationStack {
            Group {
                if translations.isEmpty {
                    ContentUnavailableView(
                        "No Translations Yet",
                        systemImage: "clock",
                        description: Text("Your translation history will appear here")
                    )
                } else {
                    List {
                        ForEach(translations) { result in
                            NavigationLink(destination: HistoryDetailView(result: result)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.sourceText)
                                        .lineLimit(1)
                                        .font(.headline)

                                    Text(result.shortTranslation ?? result.translatedText.strippingMarkdown)
                                        .lineLimit(1)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 6) {
                                        if let sourceLanguage = result.sourceLanguage {
                                            LanguageBadge(sourceLanguage)
                                        }

                                        LanguageBadge("→ \(result.targetLanguage)")
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(translations[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .task {
                purgeOldEntries()
            }
        }
    }

    private func purgeOldEntries() {
        guard allTranslations.count > 50 else { return }
        for entry in allTranslations.dropFirst(50) {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

#Preview {
    HistoryView()
}
