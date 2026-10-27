import SwiftUI
import SwiftData

/// Language bar → translation, driven by a `TranslationSession`.
/// Placed under `TranslationInputBox` in TranslationView and ActionView.
/// The language bar is shown before the first request too, so the target language can be picked up front.
public struct TranslationResultView: View {
    private let session: TranslationSession

    @Environment(\.modelContext) private var modelContext

    public init(session: TranslationSession) {
        self.session = session
    }

    public var body: some View {
        languageBar

        if session.sourceText != nil {
            TranslationBox(error: session.error, isLoading: session.isTranslating && session.translatedText.isEmpty) {
                TranslationContentView(
                    normalForm: session.normalForm,
                    synonyms: session.synonyms,
                    translatedText: session.translatedText,
                    examples: session.examples
                )
            }
        }
    }

    private var languageBar: some View {
        LanguagePair {
            if session.sourceText == nil {
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
                    fallbackLabel: session.sourceLanguage ?? "Auto-detect",
                    isDisabled: session.isTranslating
                ) { lang in
                    session.selectSourceLanguage(lang, modelContext: modelContext)
                } label: { name in
                    LanguageChip(title: name)
                }
                .tint(.primary)
            }
        } target: {
            let current = session.targetLanguage ?? SettingsManager.shared.settings.targetLanguage
            Menu {
                Picker("Target Language", selection: Binding(
                    get: { current },
                    set: { session.selectTargetLanguage($0, modelContext: modelContext) }
                )) {
                    ForEach(TranslationSettings.supportedLanguages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
            } label: {
                LanguageChip(title: current)
            }
            .tint(.primary)
        }
    }
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

/// Group box showing an error, a loading indicator, or the content.
public struct TranslationBox<Content: View>: View {
    private let error: String?
    private let isLoading: Bool
    private let content: Content

    public init(error: String? = nil, isLoading: Bool = false, @ViewBuilder content: () -> Content) {
        self.error = error
        self.isLoading = isLoading
        self.content = content()
    }

    public var body: some View {
        GroupBox {
            if let error {
                ErrorLabel(error)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
