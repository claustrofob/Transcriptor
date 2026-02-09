import Foundation

public struct TranslationSettings: Codable, Sendable, Equatable {

    public var targetLanguage: String
    public var detailLevel: DetailLevel
    public var model: GeminiModel

    private enum CodingKeys: String, CodingKey {
        case targetLanguage, detailLevel, model
    }

    public init(targetLanguage: String, detailLevel: DetailLevel, model: GeminiModel) {
        self.targetLanguage = targetLanguage
        self.detailLevel = detailLevel
        self.model = model
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetLanguage = try container.decode(String.self, forKey: .targetLanguage)
        detailLevel = try container.decode(DetailLevel.self, forKey: .detailLevel)
        model = try container.decode(GeminiModel.self, forKey: .model)
    }

    public enum DetailLevel: String, Codable, CaseIterable, Sendable {
        case concise
        case standard
        case detailed

        public var displayName: String {
            switch self {
            case .concise: "Concise"
            case .standard: "Standard"
            case .detailed: "Detailed"
            }
        }

        public var description: String {
            switch self {
            case .concise: "Direct translation only"
            case .standard: "Translation with brief context"
            case .detailed: "Thorough translation with explanations"
            }
        }
    }

    public enum GeminiModel: String, Codable, CaseIterable, Sendable {
        case gemini25Flash = "gemini-2.5-flash"
        case gemini25FlashLite = "gemini-2.5-flash-lite"
        case gemini25Pro = "gemini-2.5-pro"

        public var displayName: String {
            switch self {
            case .gemini25Flash: "Gemini 2.5 Flash"
            case .gemini25FlashLite: "Gemini 2.5 Flash Lite (Fast)"
            case .gemini25Pro: "Gemini 2.5 Pro (Quality)"
            }
        }
    }

    public static let `default` = TranslationSettings(
        targetLanguage: "Russian",
        detailLevel: .standard,
        model: .gemini25Flash
    )

    public static let supportedLanguages = [
        "Russian", "English", "Spanish", "French", "German",
        "Chinese", "Japanese", "Korean", "Portuguese", "Italian",
        "Arabic", "Hindi", "Turkish", "Dutch", "Polish",
        "Swedish", "Czech", "Greek", "Hebrew", "Thai"
    ]
}
