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
    /// Earlier versions tracked source languages under "sourceLanguageFrequencyV2"; that data is ignored.
    static let storageKey = "targetLanguageFrequency"
    private let key = storageKey
    private let maxPreferred = 4
    private let windowDays = 30

    private init() {
        self.defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    /// Initializer for testing — injects a custom UserDefaults instance.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Exposes the underlying UserDefaults for test assertions.
    var testDefaults: UserDefaults { defaults }

    /// Records a usage event for the given ISO language code.
    /// Old entries outside the 30-day window are pruned on each write.
    public func record(code: String) {
        var data = load()
        let today = dateKey(for: .now)
        data[code, default: [:]][today, default: 0] += 1

        let cutoff = dateKey(daysAgo: windowDays)
        for langCode in data.keys {
            data[langCode] = data[langCode]?.filter { $0.key > cutoff }
            if data[langCode]?.isEmpty == true { data.removeValue(forKey: langCode) }
        }

        defaults.set(data, forKey: key)
    }

    /// Up to 4 most-used languages over the last 30 days, sorted by frequency descending.
    public var preferred: [TranslationSettings.SourceLanguage] {
        let data = load()
        let cutoff = dateKey(daysAgo: windowDays)

        var totals: [String: Int] = [:]
        for (code, dayCounts) in data {
            let sum = dayCounts.filter { $0.key > cutoff }.values.reduce(0, +)
            if sum > 0 { totals[code] = sum }
        }

        return TranslationSettings.sourceLanguages
            .filter { totals[$0.code, default: 0] > 0 }
            .sorted { totals[$0.code, default: 0] > totals[$1.code, default: 0] }
            .prefix(maxPreferred)
            .map { $0 }
    }

    // MARK: - Helpers

    /// "YYYY-MM-DD" string for a given date — lexicographic order matches chronological order.
    private func dateKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func dateKey(daysAgo days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        return dateKey(for: date)
    }

    private func load() -> [String: [String: Int]] {
        defaults.dictionary(forKey: key) as? [String: [String: Int]] ?? [:]
    }
}
