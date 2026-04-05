import Foundation
import CryptoKit

enum TravelVaultCryptoService {
    private static let recoverySecretByteCount = 32
    private static let syncKeyByteCount = 32
    private static let schemaVersion = 1

    static func generateRecoverySecret() throws -> Data {
        try EncryptionService.generateRandomBytes(recoverySecretByteCount)
    }

    static func formatRecoveryKey(_ recoverySecret: Data) -> String {
        TravelVaultFormatting.group(Base32.encode(recoverySecret), every: 4)
    }

    static func parseRecoveryKey(_ input: String) throws -> Data {
        let secret = try Base32.decode(input)
        guard secret.count == recoverySecretByteCount else {
            throw TravelVaultError.invalidRecoveryKey
        }
        return secret
    }

    static func normalizePickupCode(_ input: String) -> String {
        input.filter(\.isNumber)
    }

    static func formatPickupCode(_ input: String) -> String {
        TravelVaultFormatting.group(normalizePickupCode(input), every: 4, separator: " ")
    }

    static func encryptPackage(_ packageData: Data, recoverySecret: Data) throws -> TravelVaultEncryptedPackage {
        let syncKeyData = try EncryptionService.generateRandomBytes(syncKeyByteCount)
        let syncKey = SymmetricKey(data: syncKeyData)
        let ciphertext = try EncryptionService.encrypt(data: packageData, key: syncKey)
        let wrappedSyncKey = try EncryptionService.encrypt(
            data: syncKeyData,
            key: deriveSyncKeyWrappingKey(from: recoverySecret)
        )
        return TravelVaultEncryptedPackage(
            schemaVersion: schemaVersion,
            wrappedSyncKey: wrappedSyncKey,
            ciphertext: ciphertext
        )
    }

    static func decryptPackage(_ encryptedPackage: TravelVaultEncryptedPackage, recoverySecret: Data) throws -> Data {
        guard TravelVaultRemoteConfig.supportedSchemaVersions.contains(encryptedPackage.schemaVersion) else {
            throw TravelVaultError.unsupportedSchemaVersion
        }
        let syncKeyData = try EncryptionService.decrypt(
            combined: encryptedPackage.wrappedSyncKey,
            key: deriveSyncKeyWrappingKey(from: recoverySecret)
        )
        let syncKey = SymmetricKey(data: syncKeyData)
        return try EncryptionService.decrypt(combined: encryptedPackage.ciphertext, key: syncKey)
    }

    private static func deriveSyncKeyWrappingKey(from recoverySecret: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: recoverySecret),
            salt: Data("localauth-travel-vault-keywrap".utf8),
            info: Data("sync-key-wrap-v1".utf8),
            outputByteCount: 32
        )
    }
}
