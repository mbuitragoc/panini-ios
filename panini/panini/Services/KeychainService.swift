import Foundation
import Security

/// Thin wrapper around the Security framework Keychain APIs.
enum KeychainService {
    /// The JWT token key used throughout the app.
    static let jwtKey = "panini.jwt"

    /// Saves a string value to the Keychain for the given key.
    /// Overwrites any existing value for that key.
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Remove existing item first to allow updates.
        delete(key: key)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Loads the string value stored for the given key, or nil if absent.
    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }

        return value
    }

    /// Deletes the Keychain item for the given key.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
