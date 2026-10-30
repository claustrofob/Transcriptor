import SwiftUI
import TranscriptorKit

struct ActionView: View {
    let sourceText: String
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            // The shared text only fills the input; the user starts the translation with Translate.
            TranslationScreen(initialText: sourceText)
                .navigationTitle("Transcriptor")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done", action: onDone)
                    }
                }
        }
    }
}

#Preview {
    ActionView(sourceText: "Hello, World! This is a test.") {
        print("Done")
    }
}
