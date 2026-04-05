import Foundation
import MultipeerConnectivity
import UIKit

@Observable
final class PeerSyncService: NSObject {
    enum Mode { case idle, advertising, browsing }
    enum SyncState: Equatable {
        case idle
        case waitingForPeer
        case negotiating(String)
        case connected(String)
        case transferring
        case completed(Int)
        case failed(String)
    }

    var mode: Mode = .idle
    var state: SyncState = .idle
    var pairingCode: String = ""

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let serviceType = "localauth"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)

    private var secureChannel = PeerSyncSecureChannel()
    private var connectedPeerID: MCPeerID?
    var onDataReceived: ((Data) -> Void)?

    // MARK: - Sender Flow / 发送端流程

    func startAdvertising() {
        pairingCode = generatePairingCode()
        mode = .advertising
        state = .waitingForPeer
        resetNegotiationState()

        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func sendData(_ data: Data) throws {
        guard let session, let peer = connectedPeerID, session.connectedPeers.contains(peer) else {
            state = .failed(String(localized: "未连接到对方设备"))
            return
        }
        guard let sessionKey = secureChannel.sessionKey else {
            state = .failed(String(localized: "安全握手尚未完成，请等待配对成功后再发送。"))
            return
        }

        state = .transferring
        let encrypted = try EncryptionService.encrypt(data: data, key: sessionKey)
        let envelope = PeerSyncEnvelope(type: .payload, nonce: nil, payload: encrypted)
        let encoded = try JSONEncoder().encode(envelope)
        try session.send(encoded, toPeers: [peer], with: .reliable)
    }

    // MARK: - Receiver Flow / 接收端流程

    func startBrowsing(withCode code: String) {
        pairingCode = code
        mode = .browsing
        state = .waitingForPeer
        resetNegotiationState()

        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    // MARK: - Stop / 停止

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        mode = .idle
        state = .idle
        resetNegotiationState()
    }

    // MARK: - Internals / 内部实现

    private func generatePairingCode() -> String {
        let chars = "0123456789"
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }

    private func resetNegotiationState() {
        secureChannel.reset()
        connectedPeerID = nil
    }

    private func sendHandshakeIfNeeded(to peerID: MCPeerID) {
        guard secureChannel.sessionKey == nil, let session, session.connectedPeers.contains(peerID) else { return }

        do {
            let envelope = try secureChannel.outboundHandshake(
                pairingCode: pairingCode,
                localPeerName: myPeerID.displayName,
                remotePeerName: peerID.displayName
            )
            let encoded = try JSONEncoder().encode(envelope)
            try session.send(encoded, toPeers: [peerID], with: .reliable)
        } catch {
            state = .failed(String(localized: "发送安全握手失败，请重新配对后再试。"))
        }
    }

    private func handleHandshake(_ envelope: PeerSyncEnvelope, from peerID: MCPeerID) {
        guard let nonce = envelope.nonce else {
            state = .failed(String(localized: "对方设备发送了无效的握手消息。"))
            return
        }

        let shouldReply = !secureChannel.hasLocalNonce

        do {
            try secureChannel.receiveHandshake(
                nonce: nonce,
                pairingCode: pairingCode,
                localPeerName: myPeerID.displayName,
                remotePeerName: peerID.displayName
            )

            if shouldReply {
                sendHandshakeIfNeeded(to: peerID)
            }

            if secureChannel.sessionKey != nil {
                state = .connected(peerID.displayName)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func handlePayload(_ envelope: PeerSyncEnvelope, from peerID: MCPeerID) {
        guard let payload = envelope.payload else {
            state = .failed(String(localized: "收到的同步数据为空。"))
            return
        }
        guard let sessionKey = secureChannel.sessionKey else {
            state = .failed(String(localized: "安全握手尚未完成，已拒绝导入数据。"))
            return
        }

        do {
            let decrypted = try EncryptionService.decrypt(combined: payload, key: sessionKey)
            onDataReceived?(decrypted)
            state = .connected(peerID.displayName)
        } catch {
            state = .failed(String(localized: "同步数据解密失败，请重新配对后重试。"))
        }
    }
}

// MARK: - MCSessionDelegate Conformance / MCSessionDelegate 协议实现

extension PeerSyncService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.connectedPeerID = peerID
                self.state = .negotiating(peerID.displayName)
                self.sendHandshakeIfNeeded(to: peerID)
            case .notConnected:
                if case .transferring = self.state {
                    self.state = .failed(String(localized: "连接在传输过程中断开，请重试。"))
                } else if self.mode != .idle {
                    self.state = .idle
                }
                self.resetNegotiationState()
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            do {
                let envelope = try JSONDecoder().decode(PeerSyncEnvelope.self, from: data)
                switch envelope.type {
                case .handshake:
                    self.handleHandshake(envelope, from: peerID)
                case .payload:
                    self.handlePayload(envelope, from: peerID)
                }
            } catch {
                self.state = .failed(String(localized: "收到无法识别的同步消息，已中止本次同步。"))
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate Conformance / MCNearbyServiceAdvertiserDelegate 协议实现

extension PeerSyncService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            guard let context,
                  let receivedCode = String(data: context, encoding: .utf8),
                  receivedCode == self.pairingCode else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, self.session)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate Conformance / MCNearbyServiceBrowserDelegate 协议实现

extension PeerSyncService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if let session = self.session {
                let contextData = self.pairingCode.data(using: .utf8)
                browser.invitePeer(peerID, to: session, withContext: contextData, timeout: 30)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
