import SwiftUI

/// Text input with clear button and a full-width action button, in a rounded card.
/// Sits at the top of the Translate screen and ActionView, above `TranslationResultView`.
/// The button follows the session phase: Translate while editing, Stop while translating,
/// Edit once the result is shown. The text can only be changed while editing.
public struct TranslationInputBox: View {
    @Binding private var text: String
    private let isFocused: FocusState<Bool>.Binding
    private let phase: TranslationSession.Phase
    private let onTranslate: () -> Void
    private let onStop: () -> Void
    private let onEdit: () -> Void

    public init(
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        phase: TranslationSession.Phase,
        onTranslate: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onEdit: @escaping () -> Void
    ) {
        self._text = text
        self.isFocused = isFocused
        self.phase = phase
        self.onTranslate = onTranslate
        self.onStop = onStop
        self.onEdit = onEdit
    }

    private var isEditing: Bool { phase == .editing }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Enter text to translate...", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .focused(isFocused)
                    .padding(.leading, 3)
                    // Not `.disabled`: a disabled field can't take focus in the same update that
                    // re-enables it, and Edit has to focus it right away.
                    .allowsHitTesting(isEditing)

                if isEditing && !text.isEmpty {
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

            Button(action: performAction) {
                ZStack {
                    // A new identity per phase: the old title slides out downward, the new one in from the top.
                    // Full button height, so each title travels all the way out of the clipped capsule.
                    Label(actionTitle, systemImage: actionImage)
                        .fontWeight(.semibold)
                        .foregroundStyle(isActionDisabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .id(phase)
                        .transition(.asymmetric(insertion: .move(edge: .top), removal: .move(edge: .bottom)))
                }
                .background(isActionDisabled ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.tint))
                .clipShape(.capsule)
                .animation(.spring(duration: 0.45, bounce: 0.35), value: phase)
            }
            .buttonStyle(.plain)
            .disabled(isActionDisabled)
        }
        .padding(12)
        // Same card look as the Translation box below it.
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: Self.cornerRadius))
        // Behind the card, so only the part outside its edges shows.
        .background {
            ZStack {
                if phase == .translating {
                    RainbowGlow(cornerRadius: Self.cornerRadius)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: phase == .translating)
        }
    }

    private static let cornerRadius: CGFloat = 20

    private var actionTitle: String {
        switch phase {
        case .editing: "Translate"
        case .translating: "Stop"
        case .result: "Edit"
        }
    }

    private var actionImage: String {
        switch phase {
        case .editing: "arrow.up"
        case .translating: "stop.fill"
        case .result: "pencil"
        }
    }

    private var isActionDisabled: Bool {
        isEditing && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func performAction() {
        switch phase {
        case .editing:
            onTranslate()
        case .translating:
            onStop()
            isFocused.wrappedValue = true
        case .result:
            onEdit()
            isFocused.wrappedValue = true
        }
    }
}

/// Rainbow glow shimmering around a rounded rectangle; shown while a translation is loading.
private struct RainbowGlow: View {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red]
    /// Seconds per full turn of the colors around the perimeter.
    private static let period: Double = 3

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.period) / Self.period
            let gradient = AngularGradient(colors: Self.colors, center: .center, angle: .degrees(turn * 360))
            let shape = RoundedRectangle(cornerRadius: cornerRadius)

            ZStack {
                // Wide, soft halo.
                shape
                    .stroke(gradient, lineWidth: 10)
                    .blur(radius: 14)
                    .opacity(0.8)
                // Tighter glow that keeps the colors readable at the edge.
                shape
                    .stroke(gradient, lineWidth: 3)
                    .blur(radius: 4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

