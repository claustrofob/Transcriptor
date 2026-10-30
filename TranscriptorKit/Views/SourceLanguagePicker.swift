import SwiftUI

/// Menu of every source language, to correct the model's detection; `label` gets the current
/// language name (`fallbackLabel` while none is selected).
public struct SourceLanguagePicker<ButtonLabel: View>: View {
    let selected: TranslationSettings.SourceLanguage?
    let fallbackLabel: String
    let isDisabled: Bool
    let onSelect: (TranslationSettings.SourceLanguage) -> Void
    let label: (String) -> ButtonLabel

    public init(
        selected: TranslationSettings.SourceLanguage?,
        fallbackLabel: String,
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

    /// A Toggle renders as a menu item with the system checkmark column, aligned like a Picker's.
    private func menuButton(for lang: TranslationSettings.SourceLanguage) -> some View {
        Toggle(lang.displayName, isOn: Binding(
            get: { lang == selected },
            set: { _ in onSelect(lang) }
        ))
    }

    public var body: some View {
        Menu {
            ForEach(TranslationSettings.sourceLanguages) { lang in
                menuButton(for: lang)
            }
        } label: {
            label(selected?.displayName ?? fallbackLabel)
        }
        .disabled(isDisabled)
    }
}
