import SwiftUI
import SwiftData
import TranscriptorKit

@main
struct TranscriptorApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try HistoryStore.makeContainer()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TranslationView()
        }
        .modelContainer(container)
    }
}
