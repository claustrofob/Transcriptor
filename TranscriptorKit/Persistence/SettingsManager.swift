import Foundation

public final class SettingsManager: @unchecked Sendable {

    public static let shared = SettingsManager()

    private let defaults: UserDefaults
    private let settingsKey = "translationSettings"

    private init() {
        self.defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    public var settings: TranslationSettings {
        get {
            guard let data = defaults.data(forKey: settingsKey),
                  let decoded = try? JSONDecoder().decode(TranslationSettings.self, from: data)
            else {
                return .default
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: settingsKey)
            }
        }
    }
}

// MARK: - Language Frequency Store

/// Tracks target language usage (one event per successful translation) over a rolling 30-day window.
/// Storage format: [languageCode: [dateString: usageCount]]
/// Languages with no usage in the past 30 days are automatically pruned.
/// Exposes up to 4 most-used languages for the preferred section of the target language menu.
public final class LanguageFrequencyStore: @unchecked Sendable {

    public static let shared = LanguageFrequencyStore()

    private let defaults: UserDefaults
    static let storageKey = "targetLanguageFrequency"
    private let maxPreferred = 4
    private let windowDays = 30

    private convenience init() {
        self.init(defaults: UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard)
    }

    /// Initializer for testing — injects a custom UserDefaults instance.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Records a usage event for the given ISO language code.
    /// Old entries outside the 30-day window are pruned on each write.
    public func record(code: String) {
        var data = load()
        data[code, default: [:]][Self.dateKey(for: .now), default: 0] += 1

        let cutoff = cutoffKey
        data = data
            .mapValues { $0.filter { $0.key > cutoff } }
            .filter { !$0.value.isEmpty }

        defaults.set(data, forKey: Self.storageKey)
    }

    /// Codes of up to 4 most-used target languages over the last 30 days, most used first.
    public var preferred: [String] {
        let cutoff = cutoffKey
        let totals = load().mapValues { $0.filter { $0.key > cutoff }.values.reduce(0, +) }
        return TranslationSettings.supportedLanguages
            .filter { totals[$0, default: 0] > 0 }
            .sorted { totals[$0, default: 0] > totals[$1, default: 0] }
            .prefix(maxPreferred)
            .map { $0 }
    }

    // MARK: - Helpers

    /// "YYYY-MM-DD" string for a given date — lexicographic order matches chronological order.
    static func dateKey(for date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    }

    private var cutoffKey: String {
        Self.dateKey(for: Calendar.current.date(byAdding: .day, value: -windowDays, to: .now) ?? .now)
    }

    private func load() -> [String: [String: Int]] {
        defaults.dictionary(forKey: Self.storageKey) as? [String: [String: Int]] ?? [:]
    }
}
