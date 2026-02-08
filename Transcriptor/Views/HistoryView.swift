import SwiftUI
import SwiftData
import TranscriptorKit

struct HistoryView: View {
    @Query(sort: \TranslationResult.createdAt, order: .reverse)
    private var translations: [TranslationResult]

    @Environment(\.modelContext) private var modelContext

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
                                        .lineLimit(2)
                                        .font(.headline)

                                    Text(result.translatedText)
                                        .lineLimit(2)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    HStack {
                                        Text(result.targetLanguage)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.fill.tertiary)
                                            .clipShape(Capsule())

                                        Spacer()

                                        Text(result.createdAt, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
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
        }
    }
}

#Preview {
    HistoryView()
}
