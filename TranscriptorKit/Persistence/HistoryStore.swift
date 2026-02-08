import Foundation
import SwiftData

public enum HistoryStore {

    public static func makeContainer() throws -> ModelContainer {
        let schema = Schema([TranslationResult.self])

        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) {
            storeURL = groupURL.appendingPathComponent("TranslationHistory.sqlite")
        } else {
            // Fallback for previews / testing
            storeURL = URL.applicationSupportDirectory.appendingPathComponent("TranslationHistory.sqlite")
        }

        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
