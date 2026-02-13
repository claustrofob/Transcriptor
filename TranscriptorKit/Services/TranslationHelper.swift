import Foundation
import SwiftData

/// Output from a translation operation, containing all fields needed by the UI.
public struct TranslationOutput: Sendable {
    public let translatedText: String
    public let sourceLanguage: String
    public let normalForm: String?
    public let synonyms: String?
    public let examples: [TranslationExample]
}

/// Shared translation logic used by both TranslationView and ActionView.
public enum TranslationHelper {

    /// Translates text using current settings, saves result to SwiftData, and returns UI output.
    @MainActor
    public static func translateAndSave(
        text: String,
        modelContext: ModelContext
    ) async throws -> TranslationOutput {
        let settings = SettingsManager.shared.settings

        let meta = try await GeminiService.shared.translateFull(
            text: text,
            settings: settings
        )

        let result = TranslationResult(
            sourceText: text,
            translatedText: meta.translatedText,
            normalForm: meta.normalForm,
            synonyms: meta.synonyms.isEmpty ? nil : meta.synonyms,
            shortTranslation: meta.shortTranslation,
            sourceLanguage: meta.sourceLanguage,
            targetLanguage: settings.targetLanguage,
            model: settings.model.rawValue,
            examples: meta.examples
        )
        modelContext.insert(result)
        try? modelContext.save()

        return TranslationOutput(
            translatedText: meta.translatedText,
            sourceLanguage: meta.sourceLanguage,
            normalForm: meta.normalForm,
            synonyms: meta.synonyms.isEmpty ? nil : meta.synonyms,
            examples: meta.examples
        )
    }
}
