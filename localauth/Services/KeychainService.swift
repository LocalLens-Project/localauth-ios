import Foundation
import Security

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData
    case unexpectedKeyReference
    case accessControlCreationFailed
    case keyGenerationFailed
    case publicKeyNotFound
    case encryptionFailed
    case decryptionFailed
}

enum KeychainService {

    // MARK: - Secure Enclave Key Pair / Secure Enclave 密钥对

    /// Generates an EC P-256 key pair inside the Secure Enclave, where the private key can never be exported / 在 Secure Enclave 内生成 EC P-256 密钥对，私钥永远无法导出
    /// Access control requires Face ID when the private key is used / 访问控制要求在使用私钥时通过 Face ID
    nonisolated static func generateSEKeyPair(tag: String) throws -> SecKey {
        // Remove any stale key that reused the same tag before creating a new pair / 生成新密钥对前，先清理复用同一 tag 的旧密钥
        deleteKey(tag: tag)

        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryAny],
            &error
        ) else {
            throw KeychainError.accessControlCreationFailed
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Data(tag.utf8),
                kSecAttrAccessControl as String: access,
            ] as [String: Any],
        ]

        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw KeychainError.keyGenerationFailed
        }
        return privateKey
    }

    /// Loads a Secure Enclave private key reference, and the system will prompt for Face ID on actual use / 加载 Secure Enclave 私钥引用，实际使用时系统会自动触发 Face ID
    nonisolated static func loadSEPrivateKey(tag: String) throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: Data(tag.utf8),
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnRef as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }
        guard let result else {
            throw KeychainError.unexpectedKeyReference
        }
        guard CFGetTypeID(result) == SecKeyGetTypeID() else {
            throw KeychainError.unexpectedKeyReference
        }
        return unsafeBitCast(result, to: SecKey.self)
    }

    // MARK: - ECIES Key Wrapping / ECIES 密钥包装

    /// Encrypts data with the Secure Enclave public key using ECIES-X963-SHA256-AESGCM / 使用 Secure Enclave 公钥通过 ECIES-X963-SHA256-AESGCM 加密数据
    nonisolated static func wrapKey(data: Data, withPublicKey publicKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            publicKey,
            .eciesEncryptionCofactorX963SHA256AESGCM,
            data as CFData,
            &error
        ) else {
            throw KeychainError.encryptionFailed
        }
        return encrypted as Data
    }

    /// Decrypts data with the Secure Enclave private key and triggers Face ID / 使用 Secure Enclave 私钥解密数据，并触发 Face ID
    nonisolated static func unwrapKey(wrappedData: Data, withPrivateKey privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionCofactorX963SHA256AESGCM,
            wrappedData as CFData,
            &error
        ) else {
            throw KeychainError.decryptionFailed
        }
        return decrypted as Data
    }

    // MARK: - Deletion / 删除

    /// Deletes the Secure Enclave key pair for the supplied tag / 删除指定 tag 对应的 Secure Enclave 密钥对
    nonisolated static func deleteKey(tag: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Data(tag.utf8),
        ]
        SecItemDelete(query as CFDictionary)
    }
}
