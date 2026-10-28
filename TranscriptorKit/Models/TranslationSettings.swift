import Foundation

public struct TranslationSettings: Codable, Sendable, Equatable {

    public var targetLanguage: String
    public var provider: Provider
    public var geminiModel: GeminiModel
    public var claudeModel: ClaudeModel

    private enum CodingKeys: String, CodingKey {
        case targetLanguage, provider, claudeModel
        // Stored under the legacy "model" key so settings saved before multi-provider support keep working.
        case geminiModel = "model"
    }

    public init(
        targetLanguage: String,
        provider: Provider = .google,
        geminiModel: GeminiModel = .gemini25Flash,
        claudeModel: ClaudeModel = .opus55
    ) {
        self.targetLanguage = targetLanguage
        self.provider = provider
        self.geminiModel = geminiModel
        self.claudeModel = claudeModel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = TranslationSettings.default
        targetLanguage = try container.decode(String.self, forKey: .targetLanguage)
        provider = try container.decodeIfPresent(Provider.self, forKey: .provider) ?? fallback.provider
        geminiModel = try container.decodeIfPresent(GeminiModel.self, forKey: .geminiModel) ?? fallback.geminiModel
        claudeModel = try container.decodeIfPresent(ClaudeModel.self, forKey: .claudeModel) ?? fallback.claudeModel
    }

    /// API model identifier of the active provider.
    public var modelID: String {
        switch provider {
        case .google: geminiModel.rawValue
        case .anthropic: claudeModel.rawValue
        case .apple: OnDeviceTranslationService.modelID
        }
    }

    public enum Provider: String, Codable, CaseIterable, Sendable {
        case google
        case anthropic
        /// Apple Intelligence on-device model; no API key.
        case apple

        public var displayName: String {
            switch self {
            case .google: "Google"
            case .anthropic: "Anthropic"
            case .apple: "On-device"
            }
        }

        public var requiresAPIKey: Bool {
            self != .apple
        }

        public var apiKeyPlaceholder: String {
            switch self {
            case .google: "AIza..."
            case .anthropic: "sk-ant-..."
            case .apple: ""
            }
        }

        /// Markdown: the domain links to the provider's API keys page.
        public var apiKeyHint: String {
            switch self {
            case .google: "Get your free API key at [aistudio.google.com](https://aistudio.google.com/apikey). Stored securely in Keychain."
            case .anthropic: "Get your API key at [platform.claude.com](https://platform.claude.com/settings/keys). Stored securely in Keychain."
            case .apple: "Apple Intelligence's on-device model: free, offline and private, but plain translation only (no dictionary details or examples). It's also used automatically when the selected provider has no API key or there's no network."
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

    public enum ClaudeModel: String, Codable, CaseIterable, Sendable {
        case opus55 = "claude-opus-5-5"
        case sonnet55 = "claude-sonnet-5-5"
        case haiku55 = "claude-haiku-5-5"

        public var displayName: String {
            switch self {
            case .opus55: "Claude Opus 5.5 (Quality)"
            case .sonnet55: "Claude Sonnet 5.5"
            case .haiku55: "Claude Haiku 5.5 (Fast)"
            }
        }

        /// Haiku has no server-side refusal fallback.
        var supportsServerFallback: Bool {
            self != .haiku55
        }
    }

    public static let `default` = TranslationSettings(
        targetLanguage: "Russian",
        provider: .google,
        geminiModel: .gemini25Flash,
        claudeModel: .opus55
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

    /// Finds the SourceLanguage for the model's `sourceLanguage` value: an ISO 639-1 code ("pl"),
    /// or the legacy "Польский (pl)" format still stored in older history entries.
    public static func sourceLanguage(fromModelString string: String) -> SourceLanguage? {
        guard let code = languageCode(fromModelString: string) else { return nil }
        return sourceLanguages.first { $0.code == code }
    }

    /// English display name for the model's `sourceLanguage` value: the name from `sourceLanguages`,
    /// else the system's English name for the code, else the string as is.
    public static func languageName(fromModelString string: String) -> String {
        if let language = sourceLanguage(fromModelString: string) {
            return language.name
        }
        if let code = languageCode(fromModelString: string),
           let name = Locale(identifier: "en").localizedString(forLanguageCode: code) {
            return name
        }
        return string
    }

    private static func languageCode(fromModelString string: String) -> String? {
        let code: String
        if let openParen = string.lastIndex(of: "("),
           let closeParen = string.lastIndex(of: ")"),
           openParen < closeParen {
            // Legacy format: the code is in the trailing "(xx)".
            code = String(string[string.index(after: openParen)..<closeParen])
        } else if string.contains("(") || string.contains(")") {
            return nil
        } else {
            code = string
        }
        let trimmed = code.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
