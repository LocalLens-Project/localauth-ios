import Foundation
import SwiftData

enum TokenAlgorithm: String, Codable, CaseIterable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
    case md5 = "MD5"

    static func parse(_ rawValue: String?) -> TokenAlgorithm? {
        guard let rawValue else { return nil }
        return TokenAlgorithm(rawValue: rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }
}

@Model
final class TokenModel {
    var id: UUID
    var issuer: String
    var account: String
    var iconName: String
    var colorHex: String
    var tier: TokenTier
    var sortOrder: Int
    var createdAt: Date
    var otpDigits: Int?
    var otpPeriod: Int?
    var otpAlgorithmRaw: String?

    // AES-GCM encrypted TOTP seed (nonce + ciphertext + tag) / 使用 AES-GCM 加密后的 TOTP 种子（nonce + ciphertext + tag）
    var encryptedSeed: Data

    // Normal tier only: AES key wrapped with the Secure Enclave public key via ECIES / 普通级专用：AES 密钥经 Secure Enclave 公钥通过 ECIES 包装后的密文
    var wrappedKey: Data?

    // Confidential tier only: local salt used with the YubiKey response to derive the key / 机密级专用：与 YubiKey 响应配合派生密钥时使用的本地盐
    var localSalt: Data?

    // Generic hardware-key tier only: hmac-secret credential identifier / 通用硬件密钥专用：hmac-secret 凭据标识符
    var hardwareCredentialID: Data?

    // Secure Enclave key-pair identifier / Secure Enclave 密钥对标识符
    var keychainTag: String

    // Decrypted seed kept only in memory and never persisted / 仅保存在内存中的解密种子，不会持久化
    @Transient var decryptedSecret: Data? = nil

    init(
        id: UUID = UUID(),
        issuer: String,
        account: String,
        iconName: String,
        colorHex: String,
        tier: TokenTier,
        sortOrder: Int,
        otpDigits: Int? = nil,
        otpPeriod: Int? = nil,
        otpAlgorithmRaw: String? = nil,
        encryptedSeed: Data,
        wrappedKey: Data? = nil,
        localSalt: Data? = nil,
        hardwareCredentialID: Data? = nil,
        keychainTag: String
    ) {
        self.id = id
        self.issuer = issuer
        self.account = account
        self.iconName = iconName
        self.colorHex = colorHex
        self.tier = tier
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.otpDigits = otpDigits
        self.otpPeriod = otpPeriod
        self.otpAlgorithmRaw = otpAlgorithmRaw
        self.encryptedSeed = encryptedSeed
        self.wrappedKey = wrappedKey
        self.localSalt = localSalt
        self.hardwareCredentialID = hardwareCredentialID
        self.keychainTag = keychainTag
    }

    var resolvedDigits: Int {
        let digits = otpDigits ?? 6
        return min(max(digits, 1), 10)
    }

    var resolvedPeriod: Int {
        let period = otpPeriod ?? 30
        return max(period, 1)
    }

    var resolvedAlgorithm: TokenAlgorithm {
        TokenAlgorithm.parse(otpAlgorithmRaw) ?? .sha1
    }
}
