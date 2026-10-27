import Foundation
import FoundationModels

/// Translates with Apple's on-device model (Foundation Models): no API key, works offline,
/// runs in the system process, so it works in the Action Extension too.
/// Uses the same prompts as the cloud providers; guided generation replaces the JSON schema.
public enum OnDeviceTranslationService {

    /// Why the on-device model can't be used right now; `nil` when it's available.
    /// The model is `Observable`, so SwiftUI views reading this update by themselves once it's ready.
    public static var unavailabilityReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in Settings to use the on-device model."
        case .unavailable(.modelNotReady):
            "The on-device model isn't on this device yet. iOS downloads it automatically; try again later."
        case .unavailable:
            "The on-device model is unavailable."
        }
    }

    /// Whether `language` (English name, e.g. "Russian") is in the model's officially supported
    /// languages; `nil` if the model isn't available or the language is unknown. Informational only:
    /// the model can still produce text in other languages, so translation isn't blocked on this.
    public static func supportsLanguage(_ language: String) -> Bool? {
        let model = SystemLanguageModel.default
        guard model.availability == .available,
              let code = TranslationSettings.sourceLanguages.first(where: { $0.name == language })?.code
        else { return nil }
        return model.supportsLocale(Locale(identifier: code))
    }

    /// Pass `sourceLanguage` (English name, e.g. "Polish") to override auto-detection.
    public static func translateFull(
        text: String,
        settings: TranslationSettings,
        translationType: TranslationType,
        sourceLanguage: String? = nil
    ) async throws -> TranslationMeta {
        if let unavailabilityReason {
            throw TranslationError.onDeviceUnavailable(unavailabilityReason)
        }

        let session = LanguageModelSession(
            instructions: PromptBuilder.translationPrompt(
                for: settings,
                translationType: translationType,
                sourceLanguageOverride: sourceLanguage
            )
        )

        do {
            switch translationType {
            case .word, .expression:
                let result = try await session.respond(to: text, generating: OnDeviceFullTranslation.self).content
                return TranslationMeta(
                    normalForm: result.normalForm,
                    synonyms: result.synonyms,
                    translatedText: result.translatedText,
                    sourceLanguage: result.sourceLanguage,
                    shortTranslation: result.shortTranslation,
                    examples: result.examples.map { TranslationExample(original: $0.original, translation: $0.translation) }
                )
            case .freeText:
                let result = try await session.respond(to: text, generating: OnDeviceTextTranslation.self).content
                return TranslationMeta(
                    normalForm: nil,
                    synonyms: nil,
                    translatedText: result.translatedText,
                    sourceLanguage: result.sourceLanguage,
                    shortTranslation: nil,
                    examples: nil
                )
            }
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .unsupportedLanguageOrLocale:
                throw TranslationError.onDeviceUnavailable("The on-device model doesn't support this language.")
            case .exceededContextWindowSize:
                throw TranslationError.onDeviceUnavailable("The text is too long for the on-device model.")
            case .guardrailViolation:
                throw TranslationError.refused(explanation: nil)
            default:
                throw error
            }
        } catch {
            if #available(iOS 27.0, *), let error = error as? LanguageModelError {
                throw mapped(error)
            }
            throw error
        }
    }

    /// iOS 27 reports model errors as `LanguageModelError` (`GenerationError` is deprecated there).
    @available(iOS 27.0, *)
    private static func mapped(_ error: LanguageModelError) -> Error {
        switch error {
        case .unsupportedLanguageOrLocale:
            TranslationError.onDeviceUnavailable("The on-device model doesn't support this language.")
        case .contextSizeExceeded:
            TranslationError.onDeviceUnavailable("The text is too long for the on-device model.")
        case .guardrailViolation, .refusal:
            TranslationError.refused(explanation: nil)
        case .unsupportedGenerationGuide(let details):
            TranslationError.onDeviceUnavailable("The on-device model rejected the response format: \(details.debugDescription)")
        default:
            error
        }
    }
}

// MARK: - Guided generation types

/// On-device counterpart of the word/expression JSON schema in `TranslationSchema`.
/// Only descriptions, no `.pattern`/`.count` constraints: the system model rejected a generation
/// guide ("unsupported generation guide"), and the prompt already states the format and counts.
@Generable
struct OnDeviceFullTranslation {
    @Guide(description: "Dictionary (lemma) form of the input in the SOURCE language: noun → nominative singular, verb → infinitive, adjective → nominative singular masculine.")
    var normalForm: String

    @Guide(description: "Synonyms in the SOURCE language, comma-separated. Empty string if none.")
    var synonyms: String

    @Guide(description: "Full translation and explanation, written entirely in the target language. Plain text, no Markdown.")
    var translatedText: String

    @Guide(description: "ISO 639-1 code of the source language: two lowercase letters, e.g. \"pl\".")
    var sourceLanguage: String

    @Guide(description: "Brief translation variants in the target language, comma-separated.")
    var shortTranslation: String

    @Guide(description: "5 to 8 usage examples covering all meanings, using different grammatical forms of the word.")
    var examples: [OnDeviceExample]
}

@Generable
struct OnDeviceExample {
    @Guide(description: "A natural sentence in the source language using the word.")
    var original: String

    @Guide(description: "The same sentence translated into the target language.")
    var translation: String
}

/// On-device counterpart of the free-text JSON schema in `TranslationSchema`.
@Generable
struct OnDeviceTextTranslation {
    @Guide(description: "Full translation of the input text, written entirely in the target language.")
    var translatedText: String

    @Guide(description: "ISO 639-1 code of the source language: two lowercase letters, e.g. \"pl\".")
    var sourceLanguage: String
}
