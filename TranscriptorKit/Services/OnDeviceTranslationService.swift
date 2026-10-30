import Foundation
import FoundationModels

/// Translates with Apple's on-device model (Foundation Models): no API key, works offline,
/// runs in the system process, so it works in the Action Extension too.
/// The model is too weak for the dictionary-style analysis, so it only produces a plain translation
/// (the free-text prompt) for any input. Also used as a fallback by `TranslationHelper`.
public enum OnDeviceTranslationService {

    /// Model identifier stored in history.
    public static let modelID = "apple-on-device"

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

    /// Whether the language with ISO 639 `code` (e.g. "ru") is in the model's officially supported
    /// languages; `nil` if the model isn't available. Informational only: the model can still
    /// produce text in other languages, so translation isn't blocked on this.
    public static func supportsLanguage(code: String) -> Bool? {
        let model = SystemLanguageModel.default
        guard model.availability == .available else { return nil }
        return model.supportsLocale(Locale(identifier: code))
    }

    /// Plain translation only, whatever the text type.
    /// Pass `sourceLanguage` (English name, e.g. "Polish") to override auto-detection.
    public static func translate(
        text: String,
        settings: TranslationSettings,
        sourceLanguage: String? = nil
    ) async throws -> TranslationMeta {
        if let unavailabilityReason {
            throw TranslationError.onDeviceUnavailable(unavailabilityReason)
        }

        let session = LanguageModelSession(
            instructions: PromptBuilder.plainTranslationPrompt(
                for: settings,
                sourceLanguageOverride: sourceLanguage
            )
        )

        do {
            let result = try await session.respond(to: text, generating: OnDeviceTranslation.self).content
            return TranslationMeta(
                textType: nil,
                normalForm: nil,
                synonyms: nil,
                translatedText: result.translatedText,
                sourceLanguage: result.sourceLanguage,
                shortTranslation: nil,
                examples: nil
            )
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .unsupportedLanguageOrLocale:
                throw unsupportedLanguage
            case .exceededContextWindowSize:
                throw textTooLong
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

    private static let unsupportedLanguage = TranslationError.onDeviceUnavailable("The on-device model doesn't support this language.")
    private static let textTooLong = TranslationError.onDeviceUnavailable("The text is too long for the on-device model.")

    /// iOS 27 reports model errors as `LanguageModelError` (`GenerationError` is deprecated there).
    @available(iOS 27.0, *)
    private static func mapped(_ error: LanguageModelError) -> Error {
        switch error {
        case .unsupportedLanguageOrLocale:
            unsupportedLanguage
        case .contextSizeExceeded:
            textTooLong
        case .guardrailViolation, .refusal:
            TranslationError.refused(explanation: nil)
        case .unsupportedGenerationGuide(let details):
            TranslationError.onDeviceUnavailable("The on-device model rejected the response format: \(details.debugDescription)")
        default:
            error
        }
    }
}

// MARK: - Guided generation type

/// On-device counterpart of the free-text JSON schema in `TranslationSchema`.
/// Only descriptions, no `.pattern`/`.count` constraints: the system model rejected a generation
/// guide ("unsupported generation guide").
@Generable
struct OnDeviceTranslation {
    @Guide(description: "Full translation of the input text, written entirely in the target language.")
    var translatedText: String

    @Guide(description: "ISO 639-1 code of the source language: two lowercase letters, e.g. \"pl\".")
    var sourceLanguage: String
}
