import Foundation
import SwiftData

@Model
public final class TranslationResult {
    public var sourceText: String
    public var translatedText: String
    public var shortTranslation: String?
    public var sourceLanguage: String?
    public var targetLanguage: String
    public var model: String
    public var createdAt: Date
    public var examplesData: Data?

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
        shortTranslation: String? = nil,
        sourceLanguage: String? = nil,
        targetLanguage: String,
        model: String,
        examples: [TranslationExample] = []
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.shortTranslation = shortTranslation
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.model = model
        self.createdAt = Date()
        self.examplesData = examples.isEmpty ? nil : (try? JSONEncoder().encode(examples))
    }
}
