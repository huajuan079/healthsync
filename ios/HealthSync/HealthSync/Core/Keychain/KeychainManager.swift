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
        do {
            let token = try get(key: .accessToken)
            return !isJWTExpired(token)
        } catch {
            return false
        }
    }

    // Decodes the JWT payload (Base64URL) and checks the `exp` claim locally.
    // No network request needed — the expiry is embedded in the token itself.
    private func isJWTExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }

        // Base64URL → Base64: replace URL-safe chars and add padding
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true  // unparseable → treat as expired
        }

        return Date().timeIntervalSince1970 >= exp
    }
}

enum KeychainError: Error {
    case unableToStore
    case unableToRead
}
