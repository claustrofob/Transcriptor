import SwiftUI
import SwiftData

/// The last 50 translations as card rows of the screen's List, newest first, under the result in
/// TranslationView and ActionView. `hiddenID` is the result currently on screen: it's already saved,
/// but stays out of the list until the result goes away. Cards carry `matchedGeometryEffect` in
/// `namespace`, so the result box (with the same ID) flows into its card. A tap opens
/// `HistoryDetailView`; swipe left (or long-press) to delete; swipe right to repeat: `onRepeat` gets
/// the entry's source text to edit and send again.
struct HistoryList: View {
    let hiddenID: PersistentIdentifier?
    let namespace: Namespace.ID
    let onRepeat: (String) -> Void

    @Query(sort: \TranslationResult.createdAt, order: .reverse)
    private var allTranslations: [TranslationResult]

    @Environment(\.modelContext) private var modelContext

    private static let limit = 50

    private var translations: [TranslationResult] {
        allTranslations.prefix(Self.limit).filter { $0.persistentModelID != hiddenID }
    }

    var body: some View {
        if !translations.isEmpty {
            Text("History")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.top, 8)
                .cardRow()
                .task(id: allTranslations.count) {
                    purgeOldEntries()
                }
        }

        ForEach(translations) { result in
            HistoryRow(result: result)
                .matchedGeometryEffect(id: AnyHashable(result.persistentModelID), in: namespace)
                .background {
                    // Hidden link: a visible one adds a disclosure chevron outside the card.
                    NavigationLink("") {
                        HistoryDetailView(result: result) {
                            onRepeat(result.sourceText)
                        }
                    }
                    .opacity(0)
                }
                .swipeActions(edge: .leading) {
                    Button("Repeat", systemImage: "arrow.uturn.backward") {
                        onRepeat(result.sourceText)
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(result)
                    }
                }
                .contextMenu {
                    Button("Repeat", systemImage: "arrow.uturn.backward") {
                        onRepeat(result.sourceText)
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(result)
                    }
                }
                .transition(.opacity)
                .cardRow()
        }
    }

    private func delete(_ result: TranslationResult) {
        withAnimation(.smooth(duration: 0.3)) {
            modelContext.delete(result)
            try? modelContext.save()
        }
    }

    private func purgeOldEntries() {
        guard allTranslations.count > Self.limit else { return }
        for entry in allTranslations.dropFirst(Self.limit) {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

/// History card: source text, short translation, languages. Same background and corners as the result box.
private struct HistoryRow: View {
    let result: TranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.sourceText)
                .lineLimit(1)
                .font(.headline)

            Text(result.shortTranslation ?? result.translatedText.strippingMarkdown)
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                if let sourceLanguage = result.sourceLanguageDisplayName {
                    Text(sourceLanguage)
                    Image(systemName: "arrow.right")
                        .imageScale(.small)
                }
                Text(result.targetLanguageDisplayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
    }
}

/// Everything saved for a history entry, in the layout of the Translate screen.
/// Repeat (next to the source text) goes back and calls `onRepeat`, like the Repeat swipe on a card.
struct HistoryDetailView: View {
    let result: TranslationResult
    let onRepeat: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Deleted once the screen is gone: the view still reads the model while it's on screen.
    @State private var isDeleting = false
    /// Repeated once the screen is gone, so the input on the Translate screen can take focus.
    @State private var isRepeating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OriginalTextBox(result.sourceText) {
                    isRepeating = true
                    dismiss()
                }

                // Read-only counterpart of the language bar on the Translate screen.
                LanguagePair {
                    Text(result.sourceLanguageDisplayName ?? "Unknown")
                } target: {
                    Text(result.targetLanguageDisplayName)
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
                    // Records saved before the type was stored have none; don't show the `.word` default for them.
                    if result.translationType != nil {
                        Label(result.classifiedType.displayName, systemImage: "textformat")
                    }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    isDeleting = true
                    dismiss()
                }
            }
        }
        .onDisappear {
            if isRepeating {
                onRepeat()
            }
            guard isDeleting else { return }
            withAnimation(.smooth(duration: 0.3)) {
                modelContext.delete(result)
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    let container = try! ModelContainer(
        for: TranslationResult.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(TranslationResult(
        sourceText: "podekscytowany",
        translatedText: "взволнованный",
        shortTranslation: "взволнованный, возбуждённый",
        sourceLanguage: "pl",
        targetLanguage: "ru",
        model: "gemini-3.5-flash-lite"
    ))
    container.mainContext.insert(TranslationResult(
        sourceText: "Good morning",
        translatedText: "Доброе утро",
        sourceLanguage: nil,
        targetLanguage: "ru",
        model: "claude-opus-5-5"
    ))
    return NavigationStack {
        List {
            HistoryList(hiddenID: nil, namespace: namespace) { _ in }
        }
        .listStyle(.plain)
    }
    .modelContainer(container)
}
