import Foundation
import CryptoKit

enum PeerSyncEnvelopeType: String, Codable {
    case handshake
    case payload
}

struct PeerSyncEnvelope: Codable {
    let type: PeerSyncEnvelopeType
    let nonce: Data?
    let payload: Data?
}

enum PeerSyncSecureChannelError: LocalizedError {
    case nonceGenerationFailed
    case invalidHandshake

    var errorDescription: String? {
        switch self {
        case .nonceGenerationFailed:
            return String(localized: "无法生成安全握手随机数，请重试。")
        case .invalidHandshake:
            return String(localized: "对方设备发送了无效的握手消息。")
        }
    }
}

struct PeerSyncSecureChannel {
    private(set) var sessionKey: SymmetricKey?
    private var localNonce: Data?
    private var remoteNonce: Data?

    var hasLocalNonce: Bool {
        localNonce != nil
    }

    mutating func reset() {
        sessionKey = nil
        localNonce = nil
        remoteNonce = nil
    }

    mutating func outboundHandshake(pairingCode: String, localPeerName: String, remotePeerName: String) throws -> PeerSyncEnvelope {
        try ensureLocalNonce()
        deriveSessionKeyIfPossible(pairingCode: pairingCode, localPeerName: localPeerName, remotePeerName: remotePeerName)
        return PeerSyncEnvelope(type: .handshake, nonce: localNonce, payload: nil)
    }

    mutating func receiveHandshake(
        nonce: Data,
        pairingCode: String,
        localPeerName: String,
        remotePeerName: String
    ) throws {
        guard !nonce.isEmpty else {
            throw PeerSyncSecureChannelError.invalidHandshake
        }

        remoteNonce = nonce
        try ensureLocalNonce()
        deriveSessionKeyIfPossible(pairingCode: pairingCode, localPeerName: localPeerName, remotePeerName: remotePeerName)
    }

    private mutating func ensureLocalNonce() throws {
        guard localNonce == nil else { return }
        do {
            localNonce = try EncryptionService.generateRandomBytes(16)
        } catch {
            throw PeerSyncSecureChannelError.nonceGenerationFailed
        }
    }

    private mutating func deriveSessionKeyIfPossible(pairingCode: String, localPeerName: String, remotePeerName: String) {
        guard sessionKey == nil, let localNonce, let remoteNonce else { return }

        let orderedNonces: (Data, Data)
        if localPeerName <= remotePeerName {
            orderedNonces = (localNonce, remoteNonce)
        } else {
            orderedNonces = (remoteNonce, localNonce)
        }

        let combined = Data(pairingCode.utf8) + orderedNonces.0 + orderedNonces.1
        sessionKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: combined),
            salt: Data("localauth-sync".utf8),
            info: Data("handshake-v2".utf8),
            outputByteCount: 32
        )
    }
}
