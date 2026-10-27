import SwiftUI

/// Text input with clear button and a full-width send button, in a rounded card.
/// Sits at the top of the Translate screen and ActionView, above `TranslationResultView`.
public struct TranslationInputBox: View {
    @Binding private var text: String
    private let isFocused: FocusState<Bool>.Binding
    private let onSubmit: () -> Void

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
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.top, 8)

            Button(action: onSubmit) {
                Label("Translate", systemImage: "arrow.up")
                    .fontWeight(.semibold)
                    .foregroundStyle(isSendDisabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(isSendDisabled ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.tint), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(isSendDisabled)
        }
        .padding(12)
        // Same card look as the Translation box below it.
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20))
    }

    // Sending while a translation is in flight is allowed: it cancels the previous request.
    private var isSendDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
