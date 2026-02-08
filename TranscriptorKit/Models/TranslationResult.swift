import Foundation
import SwiftData

@Model
public final class TranslationResult {
    public var sourceText: String
    public var translatedText: String
    public var shortTranslation: String?
    public var targetLanguage: String
    public var model: String
    public var createdAt: Date

    public init(
        sourceText: String,
        translatedText: String,
        shortTranslation: String? = nil,
        targetLanguage: String,
        model: String
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.shortTranslation = shortTranslation
        self.targetLanguage = targetLanguage
        self.model = model
        self.createdAt = Date()
    }
}
