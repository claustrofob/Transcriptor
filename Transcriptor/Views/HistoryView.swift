import SwiftUI
import SwiftData
import TranscriptorKit

struct HistoryView: View {
    @Query(sort: \TranslationResult.createdAt, order: .reverse)
    private var allTranslations: [TranslationResult]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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

                                    HStack(spacing: 4) {
                                        if let sourceLanguage = result.sourceLanguageName {
                                            Text(sourceLanguage)
                                            Image(systemName: "arrow.right")
                                                .imageScale(.small)
                                        }
                                        Text(result.targetLanguage)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
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
    let container = try! ModelContainer(
        for: TranslationResult.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(TranslationResult(
        sourceText: "podekscytowany",
        translatedText: "взволнованный",
        shortTranslation: "взволнованный, возбуждённый",
        sourceLanguage: "pl",
        targetLanguage: "Russian",
        model: "gemini-3.8-flash"
    ))
    container.mainContext.insert(TranslationResult(
        sourceText: "Good morning",
        translatedText: "Доброе утро",
        sourceLanguage: nil,
        targetLanguage: "Russian",
        model: "claude-opus-5-5"
    ))
    return HistoryView()
        .modelContainer(container)
}
