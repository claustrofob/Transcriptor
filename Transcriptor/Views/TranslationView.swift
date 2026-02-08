import SwiftUI
import SwiftData
import TranscriptorKit

struct TranslationView: View {
    @State private var sourceText = ""
    @State private var translatedText = ""
    @State private var isTranslating = false
    @State private var error: String?
    @State private var showClipboardAlert = false
    @State private var clipboardText = ""

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    TextEditor(text: $sourceText)
                        .frame(minHeight: 100, maxHeight: 200)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                }
                .padding(.top)

                // Translate button
                Button {
                    Task { await translate() }
                } label: {
                    HStack {
                        if isTranslating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isTranslating ? "Translating..." : "Translate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranslating)
                .padding()

                Divider()

                // Translation result
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let error {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .padding()
                        } else if !translatedText.isEmpty {
                            Text("Translation")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(translatedText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ContentUnavailableView(
                                "No Translation",
                                systemImage: "text.bubble",
                                description: Text("Enter text above and tap Translate")
                            )
                        }
                    }
                    .padding()
                }

                // Copy button
                if !translatedText.isEmpty {
                    Button {
                        UIPasteboard.general.string = translatedText
                    } label: {
                        Label("Copy Translation", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Transcriptor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sourceText = ""
                        translatedText = ""
                        error = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(sourceText.isEmpty && translatedText.isEmpty)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkClipboard()
                }
            }
            .alert("Translate from Clipboard?", isPresented: $showClipboardAlert) {
                Button("Translate") {
                    sourceText = clipboardText
                    Task { await translate() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(clipboardText.prefix(200) + (clipboardText.count > 200 ? "..." : ""))
            }
        }
    }

    // MARK: - Translation

    private func translate() async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTranslating = true
        translatedText = ""
        error = nil

        let settings = SettingsManager.shared.settings
        let stream = GeminiService.shared.translateStreaming(text: text, settings: settings)

        do {
            for try await token in stream {
                translatedText += token
            }
            // Save to history
            let result = TranslationResult(
                sourceText: text,
                translatedText: translatedText,
                targetLanguage: settings.targetLanguage,
                model: settings.model.rawValue
            )
            modelContext.insert(result)
            try? modelContext.save()
        } catch {
            self.error = error.localizedDescription
        }

        isTranslating = false
    }

    // MARK: - Clipboard

    private func checkClipboard() {
        guard sourceText.isEmpty,
              UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        clipboardText = text
        showClipboardAlert = true
    }
}

#Preview {
    TranslationView()
}
