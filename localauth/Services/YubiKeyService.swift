import Foundation
import CryptoKit
import OSLog
import YubiKit

enum YubiKeyError: Error {
    case nfcNotAvailable
    case sessionUnavailable
    case connectionFailed
    case challengeResponseFailed
    case invalidResponse
}

extension YubiKeyError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .nfcNotAvailable:
            return String(localized: "此设备不支持 NFC，无法使用 YubiKey 通道。")
        case .sessionUnavailable:
            return String(localized: "无法建立 YubiKey 会话，请重试。")
        case .connectionFailed:
            return String(localized: "YubiKey 连接中断，请重新贴近。")
        case .challengeResponseFailed:
            return String(localized: "YubiKey 未能完成挑战响应，请确认已配置 Slot 2 的 HMAC-SHA1 challenge-response。")
        case .invalidResponse:
            return String(localized: "YubiKey 返回的数据无效，请重试。")
        }
    }
}

final class YubiKeyService: NSObject, YKFManagerDelegate {
    static let shared = YubiKeyService()
    private let logger = Logger(subsystem: OpenSourceProjectInfo.publicAppIdentifier, category: "YubiKey")

    private struct PendingOperation {
        let challenge: Data
        let continuation: CheckedContinuation<Data, Error>
    }

    private var pendingOperation: PendingOperation?
    private var nfcConnection: YKFNFCConnection?

    private override init() {
        super.init()
        YubiKitManager.shared.delegate = self
        YubiKitExternalLocalization.nfcScanAlertMessage = String(localized: "请将 YubiKey 贴近手机顶部")
    }

    func didConnectAccessory(_ connection: YKFAccessoryConnection) {}

    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: (any Error)?) {}

    /// Performs HMAC-SHA1 challenge-response using Slot 2 / 使用 Slot 2 执行 HMAC-SHA1 challenge-response
    func performChallengeResponse(challenge: Data) async throws -> Data {
        guard YubiKitDeviceCapabilities.supportsISO7816NFCTags else {
            logger.error("NFC unavailable")
            throw YubiKeyError.nfcNotAvailable
        }

        guard pendingOperation == nil else {
            logger.warning("Rejected concurrent YubiKey request")
            throw YubiKeyError.sessionUnavailable
        }

        await HardwareKeyDiagnosticsCenter.shared.begin("YubiKey 挑战响应")
        await HardwareKeyDiagnosticsCenter.shared.record("challenge 长度: \(challenge.count)")
        logger.debug("Starting challenge-response")

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingOperation = PendingOperation(challenge: challenge, continuation: continuation)
            self.openChallengeResponseChannel()
        }
    }

    /// Generates a token-specific challenge value / 为令牌生成唯一挑战值
    static func challengeForToken(id: UUID) -> Data {
        let hash = SHA256.hash(data: Data(id.uuidString.utf8))
        return Data(hash.prefix(32))
    }

    private func openChallengeResponseChannel() {
        if let connection = nfcConnection {
            logger.debug("Using NFC connection")
            recordDiagnostic("复用 NFC 通道")
            executeChallengeResponse(onNFC: connection)
            return
        }
        logger.debug("Opening YubiKey NFC connection")
        recordDiagnostic("启动 NFC 连接")
        YubiKitManager.shared.startNFCConnection()
    }

    private func executeChallengeResponse(onNFC connection: YKFNFCConnection) {
        guard let challenge = pendingOperation?.challenge else {
            failCurrent(YubiKeyError.sessionUnavailable)
            return
        }

        logger.debug("Executing NFC challenge-response")
        recordDiagnostic("通过 NFC 发送 challenge")
        connection.challengeResponseSession { session, error in
            guard let session else {
                self.failCurrent(error ?? YubiKeyError.sessionUnavailable)
                return
            }
            self.recordDiagnostic("NFC challenge-response 会话已建立")
            session.sendChallenge(challenge, slot: .two) { response, sendError in
                guard sendError == nil else {
                    self.failCurrent(sendError ?? YubiKeyError.challengeResponseFailed)
                    return
                }
                guard let response, response.count >= 20 else {
                    self.failCurrent(YubiKeyError.invalidResponse)
                    return
                }
                self.recordDiagnostic("NFC 响应成功，长度 \(response.count)")
                self.completeCurrent(with: Data(response.prefix(20)))
            }
        }
    }

    private func completeCurrent(with response: Data) {
        guard let operation = pendingOperation else { return }
        pendingOperation = nil
        logger.debug("Challenge-response completed")
        recordDiagnostic("操作完成")
        stopConnections()
        Task {
            await HardwareKeyDiagnosticsCenter.shared.end(success: true)
        }
        operation.continuation.resume(returning: response)
    }

    private func failCurrent(_ error: Error) {
        guard let operation = pendingOperation else { return }
        pendingOperation = nil
        logger.error("Challenge-response failed: \(error.localizedDescription, privacy: .public)")
        recordDiagnostic("操作失败: \(error.localizedDescription)")
        stopConnections()
        Task {
            await HardwareKeyDiagnosticsCenter.shared.end(success: false)
        }
        operation.continuation.resume(throwing: error)
    }

    private func stopConnections() {
        logger.debug("Stopping YubiKey connections")
        YubiKitManager.shared.stopNFCConnection()
        nfcConnection = nil
    }

    private func recordDiagnostic(_ message: String) {
        Task {
            await HardwareKeyDiagnosticsCenter.shared.record("YubiKey: \(message)")
        }
    }

    // MARK: - YKFManagerDelegate Conformance / YKFManagerDelegate 协议实现

    func didConnectNFC(_ connection: YKFNFCConnection) {
        logger.debug("NFC connected")
        recordDiagnostic("NFC 已连接")
        nfcConnection = connection
        if pendingOperation != nil {
            executeChallengeResponse(onNFC: connection)
        }
    }

    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        logger.debug("NFC disconnected: \(error?.localizedDescription ?? "正常断开", privacy: .public)")
        recordDiagnostic("NFC 已断开")
        if nfcConnection === connection {
            nfcConnection = nil
        }
        if pendingOperation != nil {
            failCurrent(error ?? YubiKeyError.connectionFailed)
        }
    }

    func didFailConnectingNFC(_ error: Error) {
        logger.error("Failed connecting NFC: \(error.localizedDescription, privacy: .public)")
        recordDiagnostic("NFC 连接失败: \(error.localizedDescription)")
        if pendingOperation != nil {
            failCurrent(error)
        }
    }
}
