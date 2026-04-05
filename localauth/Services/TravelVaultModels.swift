import Foundation

enum TravelVaultTokenStorageMode: String, Codable, Sendable {
    case portableSecret
    case sealedTokenShell
}

struct TravelVaultTokenItem: Codable, Sendable {
    let issuer: String
    let account: String
    let secretBase32: String?
    let iconName: String
    let colorHex: String
    let tier: TokenTier
    let digits: Int
    let period: Int
    let algorithm: TokenAlgorithm
    let storageMode: TravelVaultTokenStorageMode?
    let tokenID: UUID?
    let encryptedSeed: Data?
    let wrappedKey: Data?
    let localSalt: Data?
    let hardwareCredentialID: Data?

    var label: String {
        if issuer.isEmpty {
            return account
        }
        return "\(issuer) (\(account))"
    }

    var resolvedStorageMode: TravelVaultTokenStorageMode {
        if let storageMode {
            return storageMode
        }
        return secretBase32 == nil ? .sealedTokenShell : .portableSecret
    }
}

struct TravelVaultPackage: Codable, Sendable {
    let schemaVersion: Int
    let createdAt: Date
    let sourceDeviceName: String
    let tokens: [TravelVaultTokenItem]
}

struct TravelVaultEncryptedPackage: Codable, Sendable {
    let schemaVersion: Int
    let wrappedSyncKey: Data
    let ciphertext: Data
}

struct TravelVaultPreparation: Sendable {
    let package: TravelVaultPackage
    let encodedPackage: Data
    let guidance: TokenImportGuidance
}

struct TravelVaultRemoteReceipt: Sendable {
    let pickupCode: String
    let expiresAt: Date
}

struct TravelVaultDownloadPayload: Sendable {
    let encryptedPackage: TravelVaultEncryptedPackage
    let expiresAt: Date
}

struct TravelVaultUploadReceipt: Sendable {
    let pickupCode: String
    let expiresAt: Date
    let recoveryKeyDisplay: String

    var shareText: String {
        """
        \(String(localized: "LocalAuth 旅行寄存恢复材料"))

        \(String(localized: "取件码"))
        \(pickupCode)

        \(String(localized: "恢复密钥"))
        \(recoveryKeyDisplay)

        \(String(localized: "过期时间"))
        \(TravelVaultFormatting.displayDate(expiresAt))

        \(String(localized: "请同时保存取件码和恢复密钥。仅凭取件码无法解密数据。"))
        """
    }
}

enum TravelVaultError: LocalizedError {
    case noTokens
    case hardwarePINRequired(tokenLabel: String)
    case secretUnavailable(tokenLabel: String)
    case sealedStateUnavailable(tokenLabel: String)
    case invalidRecoveryKey
    case invalidPackage
    case unsupportedSchemaVersion
    case remoteNotConfigured
    case appAttestNotSupported
    case deviceChallengeFailed
    case deviceAttestationFailed
    case invalidRemoteResponse
    case remoteNetworkUnavailable
    case remoteTimedOut
    case remoteAccessBlocked
    case remoteSecureConnectionFailed
    case remoteRateLimited
    case remotePayloadTooLarge
    case remoteFailure(message: String)

    var errorDescription: String? {
        switch self {
        case .noTokens:
            return String(localized: "当前没有可用于旅行寄存的令牌。")
        case .hardwarePINRequired(let tokenLabel):
            return String(format: String(localized: "处理“%@”时需要输入硬件密钥PIN。"), tokenLabel)
        case .secretUnavailable(let tokenLabel):
            return String(format: String(localized: "无法读取“%@”的密钥内容，请先完成解锁后再试。"), tokenLabel)
        case .sealedStateUnavailable(let tokenLabel):
            return String(format: String(localized: "无法读取“%@”的当前密文状态，请检查令牌数据是否完整。"), tokenLabel)
        case .invalidRecoveryKey:
            return String(localized: "恢复密钥无效，请检查输入内容。")
        case .invalidPackage:
            return String(localized: "旅行寄存数据损坏或格式无效，无法继续恢复。")
        case .unsupportedSchemaVersion:
            return String(localized: "当前应用版本暂不支持该旅行寄存数据格式。")
        case .remoteNotConfigured:
            return OpenSourceProjectInfo.travelVaultRemoteNotConfiguredMessage
        case .appAttestNotSupported:
            return String(localized: "当前设备不支持旅行寄存所需的官方设备证明。请使用真机并保持系统版本为 iOS 14 或更高。")
        case .deviceChallengeFailed:
            return String(localized: "无法获取旅行寄存的设备证明挑战，请稍后重试。")
        case .deviceAttestationFailed:
            return OpenSourceProjectInfo.travelVaultDeviceAttestationMessage
        case .invalidRemoteResponse:
            return String(localized: "云端返回的数据格式无效，请检查 Worker 实现。")
        case .remoteNetworkUnavailable:
            return String(localized: "当前网络可能无法稳定访问旅行寄存服务器，请稍后重试，或改用自定义域名/其他网络。")
        case .remoteTimedOut:
            return String(localized: "连接旅行寄存服务器超时，请稍后重试，或改用自定义域名/其他网络。")
        case .remoteAccessBlocked:
            return OpenSourceProjectInfo.travelVaultAccessBlockedMessage
        case .remoteSecureConnectionFailed:
            return String(localized: "旅行寄存服务器的安全连接失败，请检查网络环境或稍后重试。")
        case .remoteRateLimited:
            return String(localized: "旅行寄存是低频紧急功能，当前操作过于频繁，请稍后再试。同一安装实例的新备份也会覆盖旧的未过期备份。")
        case .remotePayloadTooLarge:
            return String(localized: "旅行寄存数据包过大，服务器已拒绝上传。请减少令牌数量后重试。")
        case .remoteFailure(let message):
            return message
        }
    }
}

enum TravelVaultFormatting {
    static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func group(_ input: String, every length: Int, separator: String = "-") -> String {
        guard length > 0 else { return input }
        let characters = Array(input)
        return stride(from: 0, to: characters.count, by: length).map { index in
            String(characters[index..<min(index + length, characters.count)])
        }.joined(separator: separator)
    }
}
