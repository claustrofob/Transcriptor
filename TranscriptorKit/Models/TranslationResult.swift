import Foundation
import SwiftData

@Model
public final class TranslationResult {
    public var sourceText: String
    public var translatedText: String
    public var normalForm: String?
    public var synonyms: String?
    public var shortTranslation: String?
    public var sourceLanguage: String?
    public var targetLanguage: String
    public var model: String
    public var createdAt: Date
    public var examplesData: Data?
    public var translationType: String?
    /// Time the provider took to respond, in seconds. Nil for records saved before it was tracked.
    public var responseDuration: TimeInterval?

    /// Typed access to the stored translation type; `.word` if it's unknown.
    public var classifiedType: TranslationType {
        translationType.flatMap(TranslationType.init(rawValue:)) ?? .word
    }

    /// Source language name for display, in the user's language ("Польский").
    public var sourceLanguageDisplayName: String? {
        sourceLanguage.map(TranslationSettings.displayName(forCode:))
    }

    /// Target language name for display, in the user's language ("Русский").
    public var targetLanguageDisplayName: String {
        TranslationSettings.displayName(forCode: targetLanguage)
    }

    /// Computed property to encode/decode examples as JSON.
    public var examples: [TranslationExample] {
        get {
            guard let data = examplesData else { return [] }
            return (try? JSONDecoder().decode([TranslationExample].self, from: data)) ?? []
        }
        set {
            examplesData = try? JSONEncoder().encode(newValue)
        }
    }

    public init(
        sourceText: String,
        translatedText: String,
        normalForm: String? = nil,
        synonyms: String? = nil,
        shortTranslation: String? = nil,
        sourceLanguage: String? = nil,
        targetLanguage: String,
        model: String,
        examples: [TranslationExample] = [],
        translationType: TranslationType = .word,
        responseDuration: TimeInterval? = nil
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.normalForm = normalForm
        self.synonyms = synonyms
        self.shortTranslation = shortTranslation
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.model = model
        self.createdAt = Date()
        self.examplesData = examples.isEmpty ? nil : (try? JSONEncoder().encode(examples))
        self.translationType = translationType.rawValue
        self.responseDuration = responseDuration
    }
}
