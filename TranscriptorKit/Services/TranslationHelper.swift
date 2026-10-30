import Foundation
import SwiftData

/// Output from a translation operation, containing all fields needed by the UI.
public struct TranslationOutput: Sendable {
    public let translatedText: String
    public let sourceLanguage: String
    public let normalForm: String?
    public let synonyms: String?
    public let examples: [TranslationExample]
    /// Set when the on-device model translated instead of the selected provider.
    public let fallbackReason: FallbackReason?
    /// The history entry saved for this translation.
    public let historyID: PersistentIdentifier
}

/// Why the on-device model was used instead of the selected cloud provider.
public enum FallbackReason: Equatable, Sendable {
    case noAPIKey(TranslationSettings.Provider)
    case network

    public var message: String {
        switch self {
        case .noAPIKey(let provider): "Translated on-device: no \(provider.displayName) API key set."
        case .network: "Translated on-device: no connection to the server."
        }
    }
}

/// Shared translation logic used by both TranslationView and ActionView.
public enum TranslationHelper {

    /// Translates (the cloud model classifies the text itself), saves the result to SwiftData, and returns UI output.
    /// Pass `sourceLanguage` (English name, e.g. "Polish") to override Gemini's auto-detection.
    @MainActor
    public static func translateAndSave(
        text: String,
        modelContext: ModelContext,
        sourceLanguage: String? = nil
    ) async throws -> TranslationOutput {
        let settings = SettingsManager.shared.settings

        let clock = ContinuousClock()
        let start = clock.now
        let (meta, modelID, fallbackReason) = try await translate(
            text: text,
            settings: settings,
            sourceLanguage: sourceLanguage
        )
        let elapsed = clock.now - start

        try Task.checkCancellation()

        // A schema-valid but hollow answer (empty translation, placeholder fields): show an error
        // with Retry instead of an empty result, and keep it out of history.
        guard !meta.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyResponse
        }

        let classification = textType(of: meta)
        // Models sometimes add whitespace or capitals to the ISO code.
        let sourceLanguage = meta.sourceLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Free text has no dictionary fields; the cloud schema still returns them as empty values.
        let isFreeText = classification == .freeText
        let normalFormValue = isFreeText ? nil : meta.normalForm.nonEmpty
        let synonymsValue = isFreeText ? nil : meta.synonyms.nonEmpty
        let shortTranslationValue = isFreeText ? nil : meta.shortTranslation.nonEmpty
        let examplesValue = isFreeText ? [] : meta.examples ?? []

        let result = TranslationResult(
            sourceText: text,
            translatedText: meta.translatedText,
            normalForm: normalFormValue,
            synonyms: synonymsValue,
            shortTranslation: shortTranslationValue,
            sourceLanguage: sourceLanguage,
            targetLanguage: settings.targetLanguage,
            model: modelID,
            examples: examplesValue,
            translationType: classification,
            responseDuration: elapsed / .seconds(1)
        )
        modelContext.insert(result)
        try? modelContext.save()

        return TranslationOutput(
            translatedText: meta.translatedText,
            sourceLanguage: sourceLanguage,
            normalForm: normalFormValue,
            synonyms: synonymsValue,
            examples: examplesValue,
            fallbackReason: fallbackReason,
            // Read after saving: the ID of an unsaved model is temporary.
            historyID: result.persistentModelID
        )
    }

    /// Translates with the selected provider. If it has no API key or the network fails and the
    /// on-device model is available, translates on-device instead. Returns the model ID actually used.
    private static func translate(
        text: String,
        settings: TranslationSettings,
        sourceLanguage: String?
    ) async throws -> (TranslationMeta, String, FallbackReason?) {
        do {
            let meta = switch settings.provider {
            case .google:
                try await GeminiService.translateFull(
                    text: text,
                    settings: settings,
                    sourceLanguage: sourceLanguage
                )
            case .anthropic:
                try await ClaudeService.translateFull(
                    text: text,
                    settings: settings,
                    sourceLanguage: sourceLanguage
                )
            case .apple:
                try await OnDeviceTranslationService.translate(
                    text: text,
                    settings: settings,
                    sourceLanguage: sourceLanguage
                )
            }
            return (meta, settings.modelID, nil)
        } catch {
            guard !Task.isCancelled,
                  let reason = fallbackReason(for: error, provider: settings.provider),
                  OnDeviceTranslationService.unavailabilityReason == nil
            else { throw error }

            let meta = try await OnDeviceTranslationService.translate(
                text: text,
                settings: settings,
                sourceLanguage: sourceLanguage
            )
            return (meta, OnDeviceTranslationService.modelID, reason)
        }
    }

    /// Class reported by the cloud model. The on-device model only does plain translation, so it
    /// reports none; an unknown value falls back to whether dictionary fields came back.
    static func textType(of meta: TranslationMeta) -> TranslationType {
        if let type = meta.textType.flatMap(TranslationType.init(rawValue:)) {
            return type
        }
        return meta.normalForm.nonEmpty == nil && (meta.examples ?? []).isEmpty ? .freeText : .word
    }

    /// Network failures that mean "no connection", as opposed to API errors or cancellation.
    private static let networkErrorCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
        .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
        .callIsActive, .secureConnectionFailed,
    ]

    /// Whether `error` from a cloud provider should fall back to the on-device model.
    static func fallbackReason(for error: Error, provider: TranslationSettings.Provider) -> FallbackReason? {
        guard provider != .apple else { return nil }
        if case TranslationError.noAPIKey = error {
            return .noAPIKey(provider)
        }
        if let urlError = error as? URLError, networkErrorCodes.contains(urlError.code) {
            return .network
        }
        return nil
    }
}
