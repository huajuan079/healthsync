import Foundation
import CryptoKit

final class AESEncryptionService: EncryptionServiceProtocol {
    static func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    func encrypt(_ data: Data, using key: SymmetricKey) throws -> EncryptedData {
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        return EncryptedData(iv: Data(nonce), tag: Data(sealedBox.tag), ciphertext: sealedBox.ciphertext)
    }

    func decrypt(_ encryptedData: EncryptedData, using key: SymmetricKey) throws -> Data {
        let nonce = try AES.GCM.Nonce(data: encryptedData.iv)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: encryptedData.ciphertext, tag: encryptedData.tag)
        return try AES.GCM.open(sealedBox, using: key)
    }

    func calculateChecksum(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
