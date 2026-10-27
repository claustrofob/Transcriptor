import SwiftUI

/// Capsule badge for displaying a language label.
public struct LanguageBadge: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.fill.tertiary)
            .clipShape(Capsule())
    }
}

/// Interactive language picker styled like a LanguageBadge.
/// Used in TranslationView and ActionView to let users correct Gemini's source language detection.
/// Pass `label` to customize the button; it receives the current language name.
public struct SourceLanguagePicker<ButtonLabel: View>: View {
    let selected: TranslationSettings.SourceLanguage?
    let fallbackLabel: String?
    let isDisabled: Bool
    let onSelect: (TranslationSettings.SourceLanguage) -> Void
    let label: (String) -> ButtonLabel

    public init(
        selected: TranslationSettings.SourceLanguage?,
        fallbackLabel: String? = nil,
        isDisabled: Bool = false,
        onSelect: @escaping (TranslationSettings.SourceLanguage) -> Void,
        @ViewBuilder label: @escaping (String) -> ButtonLabel
    ) {
        self.selected = selected
        self.fallbackLabel = fallbackLabel
        self.isDisabled = isDisabled
        self.onSelect = onSelect
        self.label = label
    }

    private var displayLabel: String {
        selected?.name ?? fallbackLabel ?? "Unknown"
    }

    private func menuButton(for lang: TranslationSettings.SourceLanguage) -> some View {
        Button {
            onSelect(lang)
        } label: {
            if lang == selected {
                Label(lang.name, systemImage: "checkmark")
            } else {
                Text(lang.name)
            }
        }
    }

    public var body: some View {
        let preferred = LanguageFrequencyStore.shared.preferred
        Menu {
            if !preferred.isEmpty {
                ForEach(preferred) { lang in
                    menuButton(for: lang)
                }
                Divider()
            }
            ForEach(TranslationSettings.sourceLanguages) { lang in
                menuButton(for: lang)
            }
        } label: {
            label(displayLabel)
        }
        .disabled(isDisabled)
    }
}

extension SourceLanguagePicker where ButtonLabel == SourceLanguageBadge {
    /// Default compact badge appearance.
    public init(
        selected: TranslationSettings.SourceLanguage?,
        fallbackLabel: String? = nil,
        isDisabled: Bool = false,
        onSelect: @escaping (TranslationSettings.SourceLanguage) -> Void
    ) {
        self.init(selected: selected, fallbackLabel: fallbackLabel, isDisabled: isDisabled, onSelect: onSelect) {
            SourceLanguageBadge(text: $0)
        }
    }
}

/// Default label of `SourceLanguagePicker`: a LanguageBadge-style capsule with a chevron.
public struct SourceLanguageBadge: View {
    let text: String

    public var body: some View {
        HStack(spacing: 3) {
            Text(text)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .imageScale(.small)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.fill.tertiary)
        .clipShape(Capsule())
    }
}
