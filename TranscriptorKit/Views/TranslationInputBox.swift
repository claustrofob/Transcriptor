import SwiftUI

/// Text input with clear button, Detail Level menu and send button, in a rounded card.
/// Sits at the top of the Translate screen and ActionView, above `TranslationResultView`.
/// The detail level is read from and saved to `SettingsManager`.
public struct TranslationInputBox: View {
    @Binding private var text: String
    private let isFocused: FocusState<Bool>.Binding
    private let onSubmit: () -> Void

    @State private var detailLevel = SettingsManager.shared.settings.detailLevel

    public init(text: Binding<String>, isFocused: FocusState<Bool>.Binding, onSubmit: @escaping () -> Void) {
        self._text = text
        self.isFocused = isFocused
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Enter text to translate...", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .focused(isFocused)
                    .padding(.leading, 3)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            // Same width as the send button so their centers line up.
                            .frame(width: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.top, 8)

            HStack(spacing: 8) {
                detailLevelMenu

                Spacer(minLength: 0)

                Button(action: onSubmit) {
                    Image(systemName: "arrow.up")
                        .fontWeight(.semibold)
                        .foregroundStyle(isSendDisabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white))
                        .frame(width: 36, height: 36)
                        .background(isSendDisabled ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.tint), in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(isSendDisabled)
                .accessibilityLabel("Translate")
            }
        }
        .padding(12)
        // Same card look as the Translation box below it.
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20))
        .onChange(of: detailLevel) { _, newValue in
            SettingsManager.shared.settings.detailLevel = newValue
        }
    }

    // Sending while a translation is in flight is allowed: it cancels the previous request.
    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var detailLevelMenu: some View {
        Menu {
            Picker("Detail Level", selection: $detailLevel) {
                ForEach(TranslationSettings.DetailLevel.allCases, id: \.self) { level in
                    Label(level.displayName, systemImage: level.systemImage).tag(level)
                }
            }
        } label: {
            OptionChip(title: detailLevel.displayName, systemImage: detailLevel.systemImage)
        }
        .tint(.primary)
        .accessibilityLabel("Detail Level: \(detailLevel.displayName)")
    }
}

private extension TranslationSettings.DetailLevel {
    /// Mirrors the shape of the formatted result: plain text, bulleted examples, numbered meanings.
    var systemImage: String {
        switch self {
        case .concise: "text.alignleft"
        case .standard: "list.bullet"
        case .detailed: "list.number"
        }
    }
}

/// Compact icon + value label used for the option menu in the input box.
private struct OptionChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.fill.tertiary, in: .capsule)
    }
}
