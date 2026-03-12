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

    /// Typed access to translation type. Old records with nil default to `.word`.
    public var classifiedType: TranslationType {
        get {
            translationType.flatMap { TranslationType(rawValue: $0) } ?? .word
        }
        set {
            translationType = newValue.rawValue
        }
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
        translationType: TranslationType = .word
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
    }
}
