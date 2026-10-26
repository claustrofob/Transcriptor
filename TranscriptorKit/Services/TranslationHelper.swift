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
        try Task.checkCancellation()

        let clock = ContinuousClock()
        let start = clock.now
        let meta = switch settings.provider {
        case .google:
            try await GeminiService.shared.translateFull(
                text: text,
                settings: settings,
                translationType: classification,
                sourceLanguage: sourceLanguage
            )
        case .anthropic:
            try await ClaudeService.shared.translateFull(
                text: text,
                settings: settings,
                translationType: classification,
                sourceLanguage: sourceLanguage
            )
        }
        let elapsed = clock.now - start

        try Task.checkCancellation()

        let synonymsValue = meta.synonyms?.isEmpty == true ? nil : meta.synonyms

        let result = TranslationResult(
            sourceText: text,
            translatedText: meta.translatedText,
            normalForm: meta.normalForm,
            synonyms: synonymsValue,
            shortTranslation: meta.shortTranslation,
            sourceLanguage: meta.sourceLanguage,
            targetLanguage: settings.targetLanguage,
            model: settings.modelID,
            examples: meta.examples ?? [],
            translationType: classification,
            responseDuration: Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
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
