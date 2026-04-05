import Foundation
import CryptoKit

enum DemoTokenCryptoService {
    static let keychainTagPrefix = "demo-mode-token-"

    private static let seedMaterial = Data("localauth-demo-mode-seed-v1".utf8)
    private static let salt = Data("localauth-demo-mode-salt".utf8)
    private static let info = Data("demo-token".utf8)

    static func encryptSecret(_ secret: Data) throws -> Data {
        try EncryptionService.encrypt(data: secret, key: demoKey)
    }

    static func decryptSecret(_ encryptedSecret: Data) throws -> Data {
        try EncryptionService.decrypt(combined: encryptedSecret, key: demoKey)
    }

    static func isDemoToken(_ token: TokenModel) -> Bool {
        token.keychainTag.hasPrefix(keychainTagPrefix)
    }

    private static var demoKey: SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: seedMaterial),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }
}
