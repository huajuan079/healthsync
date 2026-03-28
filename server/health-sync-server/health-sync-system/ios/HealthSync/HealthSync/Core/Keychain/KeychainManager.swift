import Foundation
import Security

enum KeychainKey: String {
    case accessToken = "com.openclaw.HealthSync.accessToken"
    case refreshToken = "com.openclaw.HealthSync.refreshToken"
}

protocol KeychainManagerProtocol {
    func set(key: KeychainKey, value: String) throws
    func get(key: KeychainKey) throws -> String
    func delete(key: KeychainKey) throws
}

final class KeychainManager: KeychainManagerProtocol {
    private let service = "com.openclaw.HealthSync"

    func set(key: KeychainKey, value: String) throws {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }

    func get(key: KeychainKey) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unableToRead
        }
        return value
    }

    func delete(key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case unableToStore
    case unableToRead
}
