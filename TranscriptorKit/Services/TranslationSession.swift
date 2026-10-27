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
    /// Target language the current result was requested in.
    public private(set) var targetLanguage: String?

    public private(set) var translatedText = ""
    /// Source language as returned by the model: an ISO 639-1 code, e.g. "pl".
    public private(set) var sourceLanguage: String?
    /// Detected or user-chosen source language; passed as an override on re-translation.
    public private(set) var selectedSourceLanguage: TranslationSettings.SourceLanguage?
    public private(set) var normalForm: String?
    public private(set) var synonyms: String?
    public private(set) var examples: [TranslationExample] = []
    public private(set) var error: String?
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

    /// Starts translating text. New text is auto-detected; the same text keeps its source language.
    /// Does nothing if the result for the same text and settings is already shown or in flight.
    public func translate(_ text: String, modelContext: ModelContext) {
        if text != sourceText {
            selectedSourceLanguage = nil
        }
        sourceText = text
        start(modelContext: modelContext)
    }

    /// Re-translates the current text, overriding source language detection.
    public func selectSourceLanguage(_ lang: TranslationSettings.SourceLanguage, modelContext: ModelContext) {
        LanguageFrequencyStore.shared.record(code: lang.code)
        selectedSourceLanguage = lang
        start(modelContext: modelContext)
    }

    /// Saves the new target language to settings and re-translates the current text.
    public func selectTargetLanguage(_ language: String, modelContext: ModelContext) {
        SettingsManager.shared.settings.targetLanguage = language
        start(modelContext: modelContext)
    }

    private func start(modelContext: ModelContext) {
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
        if parameters == lastParameters, error == nil {
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
            if lang == nil {
                selectedSourceLanguage = TranslationSettings.sourceLanguage(fromModelString: output.sourceLanguage)
                if let code = selectedSourceLanguage?.code {
                    LanguageFrequencyStore.shared.record(code: code)
                }
                // The detected language becomes part of the request: picking it again changes nothing.
                lastParameters?.sourceLanguageCode = selectedSourceLanguage?.code
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
