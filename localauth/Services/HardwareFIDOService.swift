import Foundation

enum HardwareFIDOError: Error {
    case pinRequired
    case unsupportedAuthenticator
    case invalidPIN
    case invalidPINAuth
    case pinBlocked
    case genericKeyUnavailable
    case credentialUnavailable
    case communicationFailed
}

extension HardwareFIDOError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .pinRequired:
            return String(localized: "当前未配置可用PIN，请先输入PIN或在设置中开启“记住PIN”。")
        case .unsupportedAuthenticator:
            return String(localized: "当前硬件密钥不支持标准 hmac-secret 流程，请确认它支持 CTAP2 与 hmac-secret 扩展。")
        case .invalidPIN:
            return String(localized: "硬件密钥PIN不正确，请重试。")
        case .invalidPINAuth:
            return String(localized: "硬件密钥拒绝了本次 PIN 认证，请重试；若 PIN 确认无误，则可能是当前设备与应用之间的 FIDO2 兼容性问题。")
        case .pinBlocked:
            return String(localized: "硬件密钥PIN已被锁定，请在对应管理工具中检查剩余重试次数或重置设备。")
        case .genericKeyUnavailable:
            return String(localized: "未检测到可用的通用硬件密钥，请使用支持 NFC 的 CTAP2 hmac-secret 设备。")
        case .credentialUnavailable:
            return String(localized: "当前令牌缺少可用的 hmac-secret 凭据标识，无法继续解锁。")
        case .communicationFailed:
            return String(localized: "硬件密钥通信失败，请重试。")
        }
    }
}

final class HardwareFIDOService {
    private let ctap2Client: CTAP2Client

    init() {
        self.ctap2Client = CTAP2Client(
            transports: [
                SystemCTAP2Transport(),
            ]
        )
    }

    func probeAuthenticator() async throws {
        await HardwareKeyDiagnosticsCenter.shared.begin("预检通用硬件密钥")
        do {
            _ = try await ctap2Client.probeInfo()
            await HardwareKeyDiagnosticsCenter.shared.end(success: true)
        } catch {
            throw await map(error)
        }
    }

    func registerHMACSecretCredential(challenge: Data, pin: String?) async throws -> CTAP2Client.HMACSecretRegistration {
        await HardwareKeyDiagnosticsCenter.shared.begin("创建通用硬件密钥令牌")
        do {
            let normalizedPIN = try normalizePIN(pin)
            let registration = try await ctap2Client.registerHMACSecretCredential(challenge: challenge, pin: normalizedPIN)
            await HardwareKeyDiagnosticsCenter.shared.end(success: true)
            return registration
        } catch {
            throw await map(error)
        }
    }

    func performHMACSecret(challenge: Data, credentialID: Data, pin: String?) async throws -> Data {
        await HardwareKeyDiagnosticsCenter.shared.begin("解锁通用硬件密钥令牌")
        do {
            let normalizedPIN = try normalizePIN(pin)
            guard !credentialID.isEmpty else {
                throw HardwareFIDOError.credentialUnavailable
            }

            let output = try await ctap2Client.requestHMACSecret(
                challenge: challenge,
                credentialID: credentialID,
                pin: normalizedPIN
            )
            await HardwareKeyDiagnosticsCenter.shared.end(success: true)
            return output
        } catch {
            throw await map(error)
        }
    }

    private func normalizePIN(_ pin: String?) throws -> String {
        let normalized = pin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty else {
            throw HardwareFIDOError.pinRequired
        }
        return normalized
    }

    private func map(_ error: Error) async -> Error {
        let mapped = baseMappedError(from: error)
        let message = userFacingMessage(for: mapped)
        await HardwareKeyDiagnosticsCenter.shared.record("错误: \(message)")
        await HardwareKeyDiagnosticsCenter.shared.end(success: false)
        let diagnostics = await HardwareKeyDiagnosticsCenter.shared.snapshot()
        return HardwareFIDOUserFacingError(message: message, diagnostics: diagnostics)
    }

    private func baseMappedError(from error: Error) -> Error {
        if let error = error as? HardwareFIDOError {
            return error
        }
        if let error = error as? CTAP2ClientError {
            switch error {
            case .unsupportedHMACSecret, .unsupportedPinProtocol:
                return HardwareFIDOError.unsupportedAuthenticator
            case .noTransport:
                return HardwareFIDOError.genericKeyUnavailable
            case .invalidResponse:
                return error
            case .operationFailed:
                return HardwareFIDOError.communicationFailed
            }
        }
        if let transportError = error as? CTAP2TransportError,
           case .ctapStatus(let status) = transportError {
            switch status {
            case 0x31:
                return HardwareFIDOError.pinRequired
            case 0x34:
                return HardwareFIDOError.pinBlocked
            case 0x32, 0x36, 0x37:
                return HardwareFIDOError.invalidPIN
            case 0x33:
                return HardwareFIDOError.invalidPINAuth
            case 0x2E:
                return HardwareFIDOError.credentialUnavailable
            default:
                return HardwareFIDOError.communicationFailed
            }
        }
        if let transportError = error as? CTAP2TransportError {
            switch transportError {
            case .notAvailable:
                return HardwareFIDOError.genericKeyUnavailable
            case .commandNotSupported:
                return HardwareFIDOError.unsupportedAuthenticator
            case .operationFailed, .timeout, .invalidResponse:
                return HardwareFIDOError.communicationFailed
            case .ctapStatus:
                return HardwareFIDOError.communicationFailed
            }
        }
        return error
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
