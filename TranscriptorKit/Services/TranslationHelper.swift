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
    /// Set when the on-device model translated instead of the selected provider.
    public let fallbackReason: FallbackReason?
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

        let classification = textType(of: meta)
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
            sourceLanguage: meta.sourceLanguage,
            targetLanguage: settings.targetLanguage,
            model: modelID,
            examples: examplesValue,
            translationType: classification,
            responseDuration: Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        )
        modelContext.insert(result)
        try? modelContext.save()

        return TranslationOutput(
            translatedText: meta.translatedText,
            sourceLanguage: meta.sourceLanguage,
            normalForm: normalFormValue,
            synonyms: synonymsValue,
            examples: examplesValue,
            translationType: classification,
            fallbackReason: fallbackReason
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
                try await GeminiService.shared.translateFull(
                    text: text,
                    settings: settings,
                    sourceLanguage: sourceLanguage
                )
            case .anthropic:
                try await ClaudeService.shared.translateFull(
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

private extension Optional where Wrapped == String {
    /// `nil` for a missing or empty string.
    var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
