import SwiftUI
import SwiftData

/// The last 50 translations as cards, newest first; shown under the result in TranslationView and ActionView.
/// `hiddenID` is the result currently on screen: it's already saved, but stays out of the list until
/// the result goes away. Cards carry `matchedGeometryEffect` in `namespace`, so the result box
/// (with the same ID) flows into its card. A tap opens `HistoryDetailView`; swipe left (or long-press)
/// to delete; swipe right to repeat: `onRepeat` gets the entry's source text to edit and send again.
struct HistoryList: View {
    let hiddenID: PersistentIdentifier?
    let namespace: Namespace.ID
    let onRepeat: (String) -> Void

    @Query(sort: \TranslationResult.createdAt, order: .reverse)
    private var allTranslations: [TranslationResult]

    @Environment(\.modelContext) private var modelContext
    /// Card whose swipe action is revealed, and on which side; only one card at a time.
    @State private var swiped: (id: PersistentIdentifier, edge: HorizontalEdge)?

    private static let limit = 50

    private var translations: [TranslationResult] {
        allTranslations.prefix(Self.limit).filter { $0.persistentModelID != hiddenID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !translations.isEmpty {
                Text("History")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.top, 8)
            }

            ForEach(translations) { result in
                let id = result.persistentModelID
                SwipeActionsCard(openEdge: Binding(
                    get: { swiped?.id == id ? swiped?.edge : nil },
                    set: { swiped = $0.map { (id, $0) } }
                )) {
                    onRepeat(result.sourceText)
                } onDelete: {
                    delete(result)
                } content: {
                    NavigationLink {
                        HistoryDetailView(result: result) {
                            onRepeat(result.sourceText)
                        }
                    } label: {
                        HistoryRow(result: result)
                            .matchedGeometryEffect(id: AnyHashable(id), in: namespace)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Repeat", systemImage: "arrow.uturn.backward") {
                            onRepeat(result.sourceText)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(result)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .task(id: allTranslations.count) {
            purgeOldEntries()
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

/// Swipe actions on a card, like `swipeActions` (which only works in a `List`; here the cards share
/// the screen's ScrollView): swipe right to reveal Repeat in front of the card, left to reveal Delete
/// behind it; swiping all the way runs the action right away. While a button is shown, a tap on
/// the card closes it instead of opening the entry.
private struct SwipeActionsCard<Content: View>: View {
    /// Side whose button is revealed; `nil` when the card is closed.
    @Binding var openEdge: HorizontalEdge?
    let onRepeat: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    /// Live horizontal translation of the swipe in progress.
    @State private var dragOffset: CGFloat = 0
    @State private var width: CGFloat = 0

    private let buttonWidth: CGFloat = 76
    private let gap: CGFloat = 8

    private var restingOffset: CGFloat {
        switch openEdge {
        case .leading: buttonWidth + gap
        case .trailing: -buttonWidth - gap
        case nil: 0
        }
    }

    private var offset: CGFloat { restingOffset + dragOffset }

    var body: some View {
        content
            .overlay {
                if openEdge != nil {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture { close() }
                }
            }
            .offset(x: offset)
            .background(alignment: .leading) {
                actionButton("Repeat", systemImage: "arrow.uturn.backward", tint: .blue, width: offset - gap) {
                    run(onRepeat)
                }
                .opacity(offset > 0 ? 1 : 0)
            }
            .background(alignment: .trailing) {
                actionButton("Delete", systemImage: "trash", tint: .red, width: -offset - gap) {
                    run(onDelete)
                }
                .opacity(offset < 0 ? 1 : 0)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .gesture(HorizontalPanGesture(onChange: { dragOffset = $0 }, onEnd: endSwipe))
            .accessibilityAction(named: "Repeat", onRepeat)
            .accessibilityAction(named: "Delete", onDelete)
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(width: max(0, width))
        .background(tint, in: .rect(cornerRadius: 20))
        .accessibilityLabel(title)
    }

    private func close() {
        withAnimation(.smooth(duration: 0.3)) { openEdge = nil }
    }

    private func run(_ action: () -> Void) {
        withAnimation(.smooth(duration: 0.3)) {
            openEdge = nil
            action()
        }
    }

    private func endSwipe(translation: CGFloat, velocity: CGFloat) {
        let finalOffset = restingOffset + translation
        withAnimation(.smooth(duration: 0.3)) {
            dragOffset = 0
            if finalOffset < -width * 0.6 {
                openEdge = nil
                onDelete()
            } else if finalOffset > width * 0.6 {
                openEdge = nil
                onRepeat()
            } else if finalOffset < -buttonWidth / 2 || (finalOffset < 0 && velocity < -300) {
                openEdge = .trailing
            } else if finalOffset > buttonWidth / 2 || (finalOffset > 0 && velocity > 300) {
                openEdge = .leading
            } else {
                openEdge = nil
            }
        }
    }
}

/// Pan that only begins when the finger moves sideways, so vertical drags still scroll the screen.
/// A SwiftUI `DragGesture` on a ScrollView's child blocks scrolling.
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    let onChange: (CGFloat) -> Void
    let onEnd: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            onChange(translation)
        case .ended, .cancelled:
            onEnd(translation, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
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
        ScrollView {
            HistoryList(hiddenID: nil, namespace: namespace) { _ in }
                .padding()
        }
    }
    .modelContainer(container)
}
