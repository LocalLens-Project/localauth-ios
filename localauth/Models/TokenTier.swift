import Foundation

enum TokenTier: String, Codable {
    case normal       // Biometrics-based unlock / 生物识别解锁
    case confidential // YubiKey hardware-key unlock / YubiKey 硬件密钥解锁
    case hardwareFIDO // Generic hardware-key unlock via CTAP2 hmac-secret / 通用硬件密钥（CTAP2 hmac-secret）解锁
}
