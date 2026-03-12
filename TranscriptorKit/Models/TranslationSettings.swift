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

    // MARK: - Source Language

    public struct SourceLanguage: Identifiable, Equatable, Sendable {
        public let name: String  // English name
        public let code: String  // ISO 639-1 / 639-2
        public var id: String { code }
    }

    public static let sourceLanguages: [SourceLanguage] = [
        SourceLanguage(name: "Afrikaans", code: "af"),
        SourceLanguage(name: "Albanian", code: "sq"),
        SourceLanguage(name: "Arabic", code: "ar"),
        SourceLanguage(name: "Armenian", code: "hy"),
        SourceLanguage(name: "Azerbaijani", code: "az"),
        SourceLanguage(name: "Basque", code: "eu"),
        SourceLanguage(name: "Belarusian", code: "be"),
        SourceLanguage(name: "Bengali", code: "bn"),
        SourceLanguage(name: "Bulgarian", code: "bg"),
        SourceLanguage(name: "Catalan", code: "ca"),
        SourceLanguage(name: "Chinese", code: "zh"),
        SourceLanguage(name: "Croatian", code: "hr"),
        SourceLanguage(name: "Czech", code: "cs"),
        SourceLanguage(name: "Danish", code: "da"),
        SourceLanguage(name: "Dutch", code: "nl"),
        SourceLanguage(name: "English", code: "en"),
        SourceLanguage(name: "Estonian", code: "et"),
        SourceLanguage(name: "Finnish", code: "fi"),
        SourceLanguage(name: "French", code: "fr"),
        SourceLanguage(name: "Galician", code: "gl"),
        SourceLanguage(name: "Georgian", code: "ka"),
        SourceLanguage(name: "German", code: "de"),
        SourceLanguage(name: "Greek", code: "el"),
        SourceLanguage(name: "Gujarati", code: "gu"),
        SourceLanguage(name: "Hebrew", code: "he"),
        SourceLanguage(name: "Hindi", code: "hi"),
        SourceLanguage(name: "Hungarian", code: "hu"),
        SourceLanguage(name: "Icelandic", code: "is"),
        SourceLanguage(name: "Indonesian", code: "id"),
        SourceLanguage(name: "Irish", code: "ga"),
        SourceLanguage(name: "Italian", code: "it"),
        SourceLanguage(name: "Japanese", code: "ja"),
        SourceLanguage(name: "Kannada", code: "kn"),
        SourceLanguage(name: "Kazakh", code: "kk"),
        SourceLanguage(name: "Korean", code: "ko"),
        SourceLanguage(name: "Latvian", code: "lv"),
        SourceLanguage(name: "Lithuanian", code: "lt"),
        SourceLanguage(name: "Macedonian", code: "mk"),
        SourceLanguage(name: "Malay", code: "ms"),
        SourceLanguage(name: "Maltese", code: "mt"),
        SourceLanguage(name: "Marathi", code: "mr"),
        SourceLanguage(name: "Norwegian", code: "no"),
        SourceLanguage(name: "Persian", code: "fa"),
        SourceLanguage(name: "Polish", code: "pl"),
        SourceLanguage(name: "Portuguese", code: "pt"),
        SourceLanguage(name: "Romanian", code: "ro"),
        SourceLanguage(name: "Russian", code: "ru"),
        SourceLanguage(name: "Serbian", code: "sr"),
        SourceLanguage(name: "Slovak", code: "sk"),
        SourceLanguage(name: "Slovenian", code: "sl"),
        SourceLanguage(name: "Spanish", code: "es"),
        SourceLanguage(name: "Swahili", code: "sw"),
        SourceLanguage(name: "Swedish", code: "sv"),
        SourceLanguage(name: "Tamil", code: "ta"),
        SourceLanguage(name: "Telugu", code: "te"),
        SourceLanguage(name: "Thai", code: "th"),
        SourceLanguage(name: "Turkish", code: "tr"),
        SourceLanguage(name: "Ukrainian", code: "uk"),
        SourceLanguage(name: "Urdu", code: "ur"),
        SourceLanguage(name: "Uzbek", code: "uz"),
        SourceLanguage(name: "Vietnamese", code: "vi"),
        SourceLanguage(name: "Welsh", code: "cy"),
    ]

    /// Parses Gemini's returned sourceLanguage string (e.g., "Польский (pl)")
    /// and finds the matching SourceLanguage by ISO code.
    public static func sourceLanguage(fromGeminiString string: String) -> SourceLanguage? {
        // Extract the ISO code from the trailing "(xx)" pattern
        guard let openParen = string.lastIndex(of: "("),
              let closeParen = string.lastIndex(of: ")"),
              openParen < closeParen else { return nil }
        let codeStart = string.index(after: openParen)
        let code = String(string[codeStart..<closeParen]).trimmingCharacters(in: .whitespaces)
        return sourceLanguages.first { $0.code == code }
    }
}
