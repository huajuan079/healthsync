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
    func hasValidToken() -> Bool
}

final class KeychainManager: KeychainManagerProtocol {
    private let service = "com.openclaw.HealthSync"

    // In-memory cache for fast access
    private var cache: [KeychainKey: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.openclaw.HealthSync.keychainCache", attributes: .concurrent)

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

        // Update cache
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = value
        }
    }

    func get(key: KeychainKey) throws -> String {
        // Check cache first
        if let cached = cacheQueue.sync(execute: { cache[key] }) {
            return cached
        }

        // Fallback to keychain
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

        // Update cache
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = value
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

        // Clear from cache
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = nil
        }
    }

    func hasValidToken() -> Bool {
        // Fast check using cache
        if cacheQueue.sync(execute: { cache[.accessToken] != nil }) {
            return true
        }

        // Fallback to synchronous check (cached after first access)
        do {
            _ = try get(key: .accessToken)
            return true
        } catch {
            return false
        }
    }
}

enum KeychainError: Error {
    case unableToStore
    case unableToRead
}
