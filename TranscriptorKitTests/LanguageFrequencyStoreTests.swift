import Testing
import Foundation
@testable import TranscriptorKit

@Suite("LanguageFrequencyStore")
struct LanguageFrequencyStoreTests {

    // Each test uses a fresh in-memory store to avoid cross-test state.

    // MARK: - record()

    @Test func recordIncreasesFrequency() {
        let store = makeStore()
        store.record(code: "pl")
        let preferred = store.preferred
        #expect(preferred.contains { $0.code == "pl" })
    }

    @Test func recordMultipleTimesIncreasesRank() {
        let store = makeStore()
        store.record(code: "pl")
        store.record(code: "pl")
        store.record(code: "de")
        let preferred = store.preferred
        #expect(preferred.first?.code == "pl")
    }

    @Test func emptyStoreReturnsEmpty() {
        let store = makeStore()
        #expect(store.preferred.isEmpty)
    }

    // MARK: - preferred() — ordering

    @Test func mostUsedLanguageIsFirst() {
        let store = makeStore()
        store.record(code: "fr")
        store.record(code: "de")
        store.record(code: "de")
        store.record(code: "de")
        let preferred = store.preferred
        #expect(preferred.first?.code == "de")
    }

    @Test func returnsAtMostFourLanguages() {
        let store = makeStore()
        ["pl", "de", "fr", "it", "es"].forEach { store.record(code: $0) }
        #expect(store.preferred.count <= 4)
    }

    @Test func onlyKnownLanguageCodesAppear() {
        let store = makeStore()
        store.record(code: "xx") // Unknown code
        store.record(code: "pl") // Known
        let preferred = store.preferred
        // "xx" has no matching SourceLanguage — must not appear
        #expect(!preferred.contains { $0.code == "xx" })
        #expect(preferred.contains { $0.code == "pl" })
    }

    // MARK: - 30-day rolling window

    @Test func oldEntriesAreExcludedFromPreferred() {
        let store = makeStore()
        // Inject a usage entry dated 31 days ago directly via record + override
        // We test the boundary by inserting data manually into UserDefaults
        let defaults = store.testDefaults
        let key = "sourceLanguageFrequencyV2"

        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: .now)!
        let oldKey = dateString(for: oldDate)
        let data: [String: [String: Int]] = ["pl": [oldKey: 5]]
        defaults.set(data, forKey: key)

        // preferred must exclude entries older than 30 days
        #expect(!store.preferred.contains { $0.code == "pl" })
    }

    @Test func entryFromTodayIsIncluded() {
        let store = makeStore()
        store.record(code: "es")
        #expect(store.preferred.contains { $0.code == "es" })
    }

    @Test func entryFromExactly30DaysAgoIsExcluded() {
        let store = makeStore()
        let defaults = store.testDefaults
        let key = "sourceLanguageFrequencyV2"

        let boundary = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let boundaryKey = dateString(for: boundary)
        let data: [String: [String: Int]] = ["de": [boundaryKey: 3]]
        defaults.set(data, forKey: key)

        // Cutoff is `> cutoff`, so exactly -30 days is excluded
        #expect(!store.preferred.contains { $0.code == "de" })
    }

    // MARK: - Pruning on write

    @Test func recordPrunesOldEntries() {
        let store = makeStore()
        let defaults = store.testDefaults
        let key = "sourceLanguageFrequencyV2"

        let staleDate = Calendar.current.date(byAdding: .day, value: -35, to: .now)!
        let staleKey = dateString(for: staleDate)
        let staleData: [String: [String: Int]] = ["pl": [staleKey: 10]]
        defaults.set(staleData, forKey: key)

        // recording today triggers pruning
        store.record(code: "fr")

        let stored = defaults.dictionary(forKey: key) as? [String: [String: Int]] ?? [:]
        // Stale "pl" entry must be removed after pruning
        #expect(stored["pl"] == nil)
    }

    // MARK: - Helpers

    private func makeStore() -> LanguageFrequencyStore {
        LanguageFrequencyStore(defaults: makeFreshDefaults())
    }

    private func makeFreshDefaults() -> UserDefaults {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return defaults
    }

    private func dateString(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
