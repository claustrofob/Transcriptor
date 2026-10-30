import Foundation
import Security

public final class KeychainService: Sendable {

    public static let shared = KeychainService()

    private init() {}

    public func saveAPIKey(_ key: String, for provider: TranslationSettings.Provider) throws {
        let query = baseQuery(for: provider)
        let data = Data(key.utf8)

        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        guard updateStatus == errSecItemNotFound else {
            guard updateStatus == errSecSuccess else { throw KeychainError.unableToSave(status: updateStatus) }
            return
        }

        var addQuery = query
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unableToSave(status: addStatus)
        }
    }

    public func loadAPIKey(for provider: TranslationSettings.Provider) -> String? {
        var query = baseQuery(for: provider)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public func deleteAPIKey(for provider: TranslationSettings.Provider) throws {
        let status = SecItemDelete(baseQuery(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status: status)
        }
    }

    /// The provider's key item in the shared access group.
    private func baseQuery(for provider: TranslationSettings.Provider) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName(for: provider),
            kSecAttrAccessGroup: AppConstants.keychainAccessGroup,
        ]
    }

    /// Google keeps the original service name so keys saved before multi-provider support are still found.
    private func serviceName(for provider: TranslationSettings.Provider) -> String {
        switch provider {
        case .google: AppConstants.keychainServiceName
        case .anthropic: "\(AppConstants.keychainServiceName).anthropic"
        case .apple: "\(AppConstants.keychainServiceName).apple"
        }
    }
}

public enum KeychainError: LocalizedError {
    case unableToSave(status: OSStatus)
    case unableToDelete(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unableToSave(let status):
            "Unable to save to Keychain (status: \(status))"
        case .unableToDelete(let status):
            "Unable to delete from Keychain (status: \(status))"
        }
    }
}
