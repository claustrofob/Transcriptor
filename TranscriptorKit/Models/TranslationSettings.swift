import Foundation

public struct TranslationSettings: Codable, Sendable, Equatable {

    /// ISO 639 code of the target language ("ru"); see `targetLanguageName` for the prompt.
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
        geminiModel: GeminiModel = .gemini35FlashLite,
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
        geminiModel = try container.decodeIfPresent(String.self, forKey: .geminiModel)
            .map(GeminiModel.init(storedValue:)) ?? fallback.geminiModel
        claudeModel = try container.decodeIfPresent(ClaudeModel.self, forKey: .claudeModel) ?? fallback.claudeModel
    }

    /// English name of the target language ("Russian"), as the model is asked to translate into it.
    public var targetLanguageName: String {
        Self.englishName(forCode: targetLanguage)
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
        case gemini35FlashLite = "gemini-3.5-flash-lite"
        case gemini38Flash = "gemini-3.8-flash"
        case gemini4Argon = "gemini-4-argon"

        public var displayName: String {
            switch self {
            case .gemini35FlashLite: "Gemini 3.5 Flash-Lite"
            case .gemini38Flash: "Gemini 3.8 Flash (Often busy)"
            case .gemini4Argon: "Gemini 4 Argon (Quality, paid)"
            }
        }

        /// Maps a stored model ID to a current model. Retired models (e.g. Gemini 2.5, which Google
        /// now serves only to its earlier users) move to the default, so old settings still decode.
        init(storedValue: String) {
            self = GeminiModel(rawValue: storedValue) ?? TranslationSettings.default.geminiModel
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
        targetLanguage: "ru",
        provider: .google,
        geminiModel: .gemini35FlashLite,
        claudeModel: .opus55
    )

    /// Target languages: a short curated list of ISO 639 codes.
    public static let supportedLanguages = [
        "ru", "en", "es", "fr", "de",
        "zh", "ja", "ko", "pt", "it",
        "ar", "hi", "tr", "nl", "pl",
        "sv", "cs", "el", "he", "th",
    ]

    // MARK: - Source Language

    public struct SourceLanguage: Identifiable, Equatable, Sendable {
        public let name: String  // English name: stored in settings and sent to the model
        public let code: String  // ISO 639 code
        public var id: String { code }

        /// Name in the user's preferred language, for display ("Польский").
        public var displayName: String {
            TranslationSettings.displayName(forCode: code)
        }
    }

    /// Every language the system has locale data for, sorted by display name.
    public static let sourceLanguages: [SourceLanguage] = {
        let codes = Set(Locale.availableIdentifiers.compactMap { Locale(identifier: $0).language.languageCode?.identifier })
        return codes
            .compactMap { code in
                // No English name means the system doesn't really know the language.
                guard let name = englishLocale.localizedString(forLanguageCode: code), name != code else { return nil }
                return SourceLanguage(name: name, code: code)
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }()

    private static let englishLocale = Locale(identifier: "en")

    /// Locale for language names in the UI: the user's first preferred language,
    /// since the app itself is English-only and `Locale.current` would name languages in English.
    private static let displayLocale = Locale(identifier: Locale.preferredLanguages.first ?? "en")

    /// Display name for an ISO 639 code, capitalized ("pl" → "Польский"); the code itself if unknown.
    public static func displayName(forCode code: String) -> String {
        guard let name = displayLocale.localizedString(forLanguageCode: code) else { return code }
        return name.prefix(1).uppercased(with: displayLocale) + name.dropFirst()
    }

    /// English name for an ISO 639 code ("pl" → "Polish"); the code itself if unknown.
    public static func englishName(forCode code: String) -> String {
        englishLocale.localizedString(forLanguageCode: code) ?? code
    }

    /// Display name for the model's `sourceLanguage` value (see `languageName(fromModelString:)`).
    public static func displayName(fromModelString string: String) -> String {
        languageCode(fromModelString: string).map(displayName(forCode:)) ?? string
    }

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
           let name = englishLocale.localizedString(forLanguageCode: code) {
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
