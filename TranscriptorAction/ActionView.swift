import SwiftUI
import TranscriptorKit

struct ActionView: View {
    let sourceText: String
    let onDone: () -> Void

    @State private var translatedText = ""
    @State private var isTranslating = true
    @State private var errorMessage: String?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Original text
                    GroupBox {
                        Text(sourceText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Original", systemImage: "text.quote")
                            .font(.caption)
                    }

                    // Translation
                    GroupBox {
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if isTranslating && translatedText.isEmpty {
                            HStack {
                                ProgressView()
                                Text("Translating...")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        } else {
                            Text(translatedText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } label: {
                        Label("Translation", systemImage: "text.bubble")
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("Transcriptor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDone() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = translatedText
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        Label(
                            copied ? "Copied!" : "Copy",
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .disabled(translatedText.isEmpty)
                }
            }
            .task { await translate() }
        }
    }

    // MARK: - Translation

    private func translate() async {
        let settings = SettingsManager.shared.settings

        guard KeychainService.shared.loadAPIKey() != nil else {
            errorMessage = "API key not configured. Please open Transcriptor and set your Google AI API key in Settings."
            isTranslating = false
            return
        }

        let stream = GeminiService.shared.translateStreaming(
            text: sourceText,
            settings: settings
        )

        do {
            for try await token in stream {
                translatedText += token
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isTranslating = false
    }
}

#Preview {
    ActionView(sourceText: "Hello, World! This is a test.") {
        print("Done")
    }
}
