import Foundation
import Observation
import SwiftData

/// State of a single on-screen translation, shared by TranslationView and ActionView.
/// Starting a new request cancels the one in flight; a cancelled request is never saved to history.
@MainActor
@Observable
public final class TranslationSession {

    /// Text being translated; `nil` until the first request.
    public private(set) var sourceText: String?
    /// Observable copy of the target language setting (`SettingsManager` isn't observable),
    /// so a pick in the language bar shows up even before the first request.
    public private(set) var targetLanguage = SettingsManager.shared.settings.targetLanguage

    public private(set) var translatedText = ""
    /// Source language as returned by the model: an ISO 639-1 code, e.g. "pl".
    public private(set) var sourceLanguage: String?
    /// Detected or user-chosen source language; passed as an override on re-translation.
    public private(set) var selectedSourceLanguage: TranslationSettings.SourceLanguage?
    public private(set) var normalForm: String?
    public private(set) var synonyms: String?
    public private(set) var examples: [TranslationExample] = []
    public private(set) var error: String?
    /// Shown above the result when the on-device model translated instead of the selected provider.
    public private(set) var fallbackNotice: String?
    public private(set) var isTranslating = false

    @ObservationIgnored private var task: Task<Void, Never>?
    /// Parameters of the latest request, in flight or finished; used to skip repeating it.
    @ObservationIgnored private var lastParameters: RequestParameters?

    /// Everything that affects a translation's result.
    struct RequestParameters: Equatable {
        var text: String
        /// Detected or user-chosen source language; `nil` means auto-detect.
        var sourceLanguageCode: String?
        var targetLanguage: String
        var provider: TranslationSettings.Provider
        var modelID: String
    }

    public init() {}

    /// Source language is unknown while the first response is pending.
    public var isDetectingSourceLanguage: Bool {
        isTranslating && selectedSourceLanguage == nil && sourceLanguage == nil
    }

    /// Always starts a new request with an auto-detected source language (the Translate button).
    public func translate(_ text: String, modelContext: ModelContext) {
        selectedSourceLanguage = nil
        sourceText = text
        start(modelContext: modelContext, force: true)
    }

    /// Re-translates the current text, overriding source language detection.
    public func selectSourceLanguage(_ lang: TranslationSettings.SourceLanguage, modelContext: ModelContext) {
        selectedSourceLanguage = lang
        start(modelContext: modelContext)
    }

    /// Saves the new target language to settings and re-translates the current text.
    public func selectTargetLanguage(_ language: String, modelContext: ModelContext) {
        SettingsManager.shared.settings.targetLanguage = language
        targetLanguage = language
        start(modelContext: modelContext)
    }

    /// `force` skips the unchanged-parameters check, which only guards the language menus
    /// against re-sending the same request when the current language is picked again.
    private func start(modelContext: ModelContext, force: Bool = false) {
        guard let sourceText else { return }

        let settings = SettingsManager.shared.settings
        let parameters = RequestParameters(
            text: sourceText,
            sourceLanguageCode: selectedSourceLanguage?.code,
            targetLanguage: settings.targetLanguage,
            provider: settings.provider,
            modelID: settings.modelID
        )
        // A failed request may be retried with the same parameters (e.g. after adding an API key).
        if !force, parameters == lastParameters, error == nil {
            return
        }
        lastParameters = parameters

        task?.cancel()
        resetResult()
        targetLanguage = settings.targetLanguage
        isTranslating = true

        let override = selectedSourceLanguage
        task = Task { await run(text: sourceText, sourceLanguage: override, modelContext: modelContext) }
    }

    private func resetResult() {
        translatedText = ""
        sourceLanguage = nil
        normalForm = nil
        synonyms = nil
        examples = []
        error = nil
        fallbackNotice = nil
    }

    /// Pass `lang` to override auto-detection; otherwise the detected language becomes the selection.
    private func run(
        text: String,
        sourceLanguage lang: TranslationSettings.SourceLanguage?,
        modelContext: ModelContext
    ) async {
        do {
            let output = try await TranslationHelper.translateAndSave(
                text: text,
                modelContext: modelContext,
                sourceLanguage: lang?.name
            )
            guard !Task.isCancelled else { return }

            translatedText = output.translatedText
            sourceLanguage = output.sourceLanguage
            if let code = TranslationSettings.sourceLanguages.first(where: { $0.name == targetLanguage })?.code {
                LanguageFrequencyStore.shared.record(code: code)
            }
            if lang == nil {
                selectedSourceLanguage = TranslationSettings.sourceLanguage(fromModelString: output.sourceLanguage)
                // The detected language becomes part of the request: picking it again changes nothing.
                lastParameters?.sourceLanguageCode = selectedSourceLanguage?.code
            }
            fallbackNotice = output.fallbackReason?.message
            if output.fallbackReason != nil {
                // Let the same request be sent again, e.g. once the network is back.
                lastParameters = nil
            }
            normalForm = output.normalForm
            synonyms = output.synonyms
            examples = output.examples
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }

        isTranslating = false
    }
}
