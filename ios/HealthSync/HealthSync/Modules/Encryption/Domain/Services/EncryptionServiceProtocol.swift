import Foundation
import CryptoKit

protocol EncryptionServiceProtocol {
    func encrypt(_ data: Data, using key: SymmetricKey) throws -> EncryptedData
    func decrypt(_ encryptedData: EncryptedData, using key: SymmetricKey) throws -> Data
    func calculateChecksum(_ data: Data) -> String
}

struct EncryptedData: Codable {
    let iv: Data
    let tag: Data
    let ciphertext: Data
    func toBase64() -> String {
        "\(iv.base64EncodedString()):\(tag.base64EncodedString()):\(ciphertext.base64EncodedString())"
    }
}

enum EncryptionError: LocalizedError {
    case encryptionFailed
    var errorDescription: String? {
        switch self { case .encryptionFailed: return "加密失败" }
    }
}
