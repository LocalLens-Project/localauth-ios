import Foundation
import CryptoKit

enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case randomGenerationFailed
}

enum EncryptionService {
    /// Encrypts with AES-256-GCM and returns combined data: nonce(12) + ciphertext + tag(16) / 使用 AES-256-GCM 加密并返回组合数据：nonce(12) + ciphertext + tag(16)
    nonisolated static func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// Decrypts AES-256-GCM combined data / 解密 AES-256-GCM 组合数据
    nonisolated static func decrypt(combined: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    /// Derives a 256-bit key from a YubiKey HMAC response and local salt using HKDF-SHA256 / 使用 HKDF-SHA256 从 YubiKey HMAC 响应与本地盐派生 256 位密钥
    nonisolated static func deriveKey(hmacResponse: Data, salt: Data) -> SymmetricKey {
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: hmacResponse),
            salt: salt,
            info: Data("localauth-confidential".utf8),
            outputByteCount: 32
        )
        return derived
    }

    /// Generates cryptographically secure random bytes / 生成密码学安全的随机字节
    nonisolated static func generateRandomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw EncryptionError.randomGenerationFailed
        }
        return Data(bytes)
    }
}
