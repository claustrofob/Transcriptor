import Foundation
import Security

public final class KeychainService: Sendable {

    public static let shared = KeychainService()

    private init() {}

    // MARK: - Save

    public func saveAPIKey(_ key: String, for provider: TranslationSettings.Provider) throws {
        let data = Data(key.utf8)

        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName(for: provider),
            kSecAttrAccessGroup as String: AppConstants.keychainAccessGroup,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, add it
            var addQuery = updateQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unableToSave(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unableToSave(status: updateStatus)
        }
    }

    // MARK: - Load

    public func loadAPIKey(for provider: TranslationSettings.Provider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName(for: provider),
            kSecAttrAccessGroup as String: AppConstants.keychainAccessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    public func deleteAPIKey(for provider: TranslationSettings.Provider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName(for: provider),
            kSecAttrAccessGroup as String: AppConstants.keychainAccessGroup,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status: status)
        }
    }

    // MARK: - Helpers

    /// Google keeps the original service name so keys saved before multi-provider support are still found.
    private func serviceName(for provider: TranslationSettings.Provider) -> String {
        switch provider {
        case .google: AppConstants.keychainServiceName
        case .anthropic: "\(AppConstants.keychainServiceName).anthropic"
        }
    }
}

// MARK: - Errors

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
