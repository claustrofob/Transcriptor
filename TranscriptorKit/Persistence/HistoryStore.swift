import Foundation
import SwiftData

public enum HistoryStore {

    public static func makeContainer() throws -> ModelContainer {
        let schema = Schema([TranslationResult.self])

        // Outside the App Group (previews, tests) the store goes to Application Support.
        let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) ?? .applicationSupportDirectory
        let configuration = ModelConfiguration(url: directory.appending(path: "TranslationHistory.sqlite"))
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
