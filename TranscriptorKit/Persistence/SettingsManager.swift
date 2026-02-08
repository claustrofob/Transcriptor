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
