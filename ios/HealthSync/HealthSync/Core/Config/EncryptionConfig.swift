import Foundation
import CryptoKit

/// Encryption configuration - keys must match server configuration
enum EncryptionConfig {
    // 32-byte hex keys (64 characters)
    // These must match the server .env configuration
    static let zhugongKeyHex = "e357cb730d462b66e83bee5e7e85b4d83ab337647f192cdea4e80151e39e8982"
    static let dageKeyHex = "e357cb730d462b66e83bee5e7e85b4d83ab337647f192cdea4e80151e39e8982"

    /// Get encryption key for username
    static func getKey(for username: String) -> SymmetricKey? {
        let hex: String?
        switch username.lowercased() {
        case "zhugong":
            hex = zhugongKeyHex
        case "dage":
            hex = dageKeyHex
        default:
            hex = nil
        }

        guard let hexString = hex,
              let data = hexString.hexData else {
            return nil
        }
        return SymmetricKey(data: data)
    }
}

// MARK: - Hex String Extension

extension String {
    /// Convert hex string to Data
    var hexData: Data? {
        var data = Data(capacity: count / 2)
        let regex = try! NSRegularExpression(pattern: "[0-9a-fA-F]{2}", options: [])
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: count))

        for match in matches {
            if let range = Range(match.range, in: self) {
                let byteString = String(self[range])
                if var num = UInt8(byteString, radix: 16) {
                    data.append(&num, count: 1)
                }
            }
        }

        return data.isEmpty ? nil : data
    }
}
