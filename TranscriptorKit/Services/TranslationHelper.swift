import Foundation
import SwiftData

/// Output from a translation operation, containing all fields needed by the UI.
public struct TranslationOutput: Sendable {
    public let translatedText: String
    public let sourceLanguage: String
    public let normalForm: String?
    public let synonyms: String?
    public let examples: [TranslationExample]
    public let translationType: TranslationType
}

/// Shared translation logic used by both TranslationView and ActionView.
public enum TranslationHelper {

    /// Classifies text, translates using appropriate prompt/schema, saves result to SwiftData, and returns UI output.
    /// Pass `sourceLanguage` (English name, e.g. "Polish") to override Gemini's auto-detection.
    @MainActor
    public static func translateAndSave(
        text: String,
        modelContext: ModelContext,
        sourceLanguage: String? = nil
    ) async throws -> TranslationOutput {
        let settings = SettingsManager.shared.settings

        let classification = await TextClassifier.classify(text)

        let meta = try await GeminiService.shared.translateFull(
            text: text,
            settings: settings,
            translationType: classification,
            sourceLanguage: sourceLanguage
        )

        let synonymsValue = meta.synonyms?.isEmpty == true ? nil : meta.synonyms

        let result = TranslationResult(
            sourceText: text,
            translatedText: meta.translatedText,
            normalForm: meta.normalForm,
            synonyms: synonymsValue,
            shortTranslation: meta.shortTranslation,
            sourceLanguage: meta.sourceLanguage,
            targetLanguage: settings.targetLanguage,
            model: settings.model.rawValue,
            examples: meta.examples ?? [],
            translationType: classification
        )
        modelContext.insert(result)
        try? modelContext.save()

        return TranslationOutput(
            translatedText: meta.translatedText,
            sourceLanguage: meta.sourceLanguage,
            normalForm: meta.normalForm,
            synonyms: synonymsValue,
            examples: meta.examples ?? [],
            translationType: classification
        )
    }
}
