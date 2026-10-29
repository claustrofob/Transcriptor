import SwiftUI
import SwiftData

/// Language bar → translation, driven by a `TranslationSession`.
/// Placed under `TranslationInputBox` in TranslationView and ActionView.
/// The language bar is always shown, so the target language can be picked up front;
/// the translation box only once the result is in.
public struct TranslationResultView: View {
    private let session: TranslationSession

    @Environment(\.modelContext) private var modelContext

    public init(session: TranslationSession) {
        self.session = session
    }

    public var body: some View {
        languageBar

        // Stable container so the box's insertion and removal run under the animation below.
        VStack(spacing: 0) {
            if session.phase == .result {
                TranslationBox(error: session.error, onRetry: { session.retry(modelContext: modelContext) }) {
                    if let fallbackNotice = session.fallbackNotice {
                        Label(fallbackNotice, systemImage: "iphone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TranslationContentView(
                        normalForm: session.normalForm,
                        synonyms: session.synonyms,
                        translatedText: session.translatedText,
                        examples: session.examples
                    )
                }
                .transition(.reveal)
            }
        }
        .animation(.smooth(duration: 0.4), value: session.phase == .result)
    }

    private var languageBar: some View {
        LanguagePair {
            // Translate always auto-detects, so there is nothing to pick while editing.
            if session.phase == .editing {
                Text("Auto-detect")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(.fill.tertiary, in: .capsule)
            } else if session.isDetectingSourceLanguage {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Detecting")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(.fill.tertiary, in: .capsule)
            } else {
                SourceLanguagePicker(
                    selected: session.selectedSourceLanguage,
                    // Nothing detected (e.g. the request failed): keep showing "Auto-detect" instead of "Unknown".
                    fallbackLabel: session.sourceLanguage.map(TranslationSettings.languageName(fromModelString:)) ?? "Auto-detect",
                    isDisabled: session.isTranslating
                ) { lang in
                    session.selectSourceLanguage(lang, modelContext: modelContext)
                } label: { name in
                    LanguageChip(title: name)
                }
                .tint(.primary)
            }
        } target: {
            let current = session.targetLanguage
            Menu {
                let preferred = preferredTargetLanguages
                if !preferred.isEmpty {
                    ForEach(preferred, id: \.self) { targetLanguageItem($0, current: current) }
                    Divider()
                }
                ForEach(TranslationSettings.supportedLanguages, id: \.self) { targetLanguageItem($0, current: current) }
            } label: {
                LanguageChip(title: current)
            }
            .tint(.primary)
        }
    }
}

private extension TranslationResultView {
    /// Most-used target languages over the last 30 days, shown above the full list.
    var preferredTargetLanguages: [String] {
        LanguageFrequencyStore.shared.preferred
            .map(\.name)
            .filter(TranslationSettings.supportedLanguages.contains)
    }

    /// A Toggle renders as a menu item with the system checkmark column; a Picker can't be used
    /// because preferred languages appear in the menu twice.
    func targetLanguageItem(_ language: String, current: String) -> some View {
        Toggle(language, isOn: Binding(
            get: { language == current },
            set: { _ in session.selectTargetLanguage(language, modelContext: modelContext) }
        ))
    }
}

/// Unrolls the view downward from its top edge (and rolls it back up on removal), fading it in.
struct RevealTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .mask(alignment: .top) {
                Rectangle()
                    .scaleEffect(x: 1, y: phase.isIdentity ? 1 : 0, anchor: .top)
            }
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

extension Transition where Self == RevealTransition {
    static var reveal: RevealTransition { RevealTransition() }
}

/// Group box with the source text.
public struct OriginalTextBox: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        GroupBox {
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(.roundedCard)
    }
}

/// Group box showing an error (with an optional Retry button), a loading indicator, or the content.
public struct TranslationBox<Content: View>: View {
    private let error: String?
    private let isLoading: Bool
    private let onRetry: (() -> Void)?
    private let content: Content

    public init(
        error: String? = nil,
        isLoading: Bool = false,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.error = error
        self.isLoading = isLoading
        self.onRetry = onRetry
        self.content = content()
    }

    public var body: some View {
        GroupBox {
            if let error {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    ErrorLabel(error)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let onRetry {
                        Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            } else if isLoading {
                HStack {
                    ProgressView()
                    Text("Translating...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                content
            }
        }
        .groupBoxStyle(.roundedCard)
    }
}

/// GroupBox with the system background but larger, continuous corners.
struct RoundedCardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
            configuration.content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20))
    }
}

extension GroupBoxStyle where Self == RoundedCardGroupBoxStyle {
    static var roundedCard: RoundedCardGroupBoxStyle { RoundedCardGroupBoxStyle() }
}

/// Source → target layout: two equal halves with the arrow centered between them.
public struct LanguagePair<Source: View, Target: View>: View {
    private let source: Source
    private let target: Target

    public init(@ViewBuilder source: () -> Source, @ViewBuilder target: () -> Target) {
        self.source = source()
        self.target = target()
    }

    public var body: some View {
        HStack(spacing: 8) {
            source
                .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            target
                .frame(maxWidth: .infinity)
        }
    }
}

/// Full-width capsule button label for a language menu.
public struct LanguageChip: View {
    private let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .imageScale(.small)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(.fill.tertiary, in: .capsule)
    }
}
