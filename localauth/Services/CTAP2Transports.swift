import Foundation
import CryptoKit

enum CTAP2TransportError: Error {
    case notAvailable
    case commandNotSupported
    case operationFailed
    case timeout
    case invalidResponse
    case ctapStatus(UInt8)
}

struct SystemCTAP2Transport: CTAP2Transport {
    let transportName = "system-ctap2"
    #if canImport(CoreNFC)
    private let coordinator = CoreNFCCTAP2Coordinator()
    #endif

    func send(command: CTAP2Command, payload: Data) async throws -> Data {
        #if canImport(CoreNFC)
        return try await coordinator.send(command: command, payload: payload)
        #else
        throw CTAP2TransportError.notAvailable
        #endif
    }

    func finish(didSucceed: Bool) async {
        #if canImport(CoreNFC)
        await coordinator.finish(didSucceed: didSucceed)
        #endif
    }

    func updateAlertMessage(_ message: String) async {
        #if canImport(CoreNFC)
        await coordinator.updateAlertMessage(message)
        #endif
    }
}

final class LegacyYubiBridgeTransport: CTAP2Transport {
    let transportName = "legacy-yubikit-bridge"
    private let yubi = YubiKeyService.shared

    func send(command: CTAP2Command, payload: Data) async throws -> Data {
        switch command {
        case .getInfo:
            return Data("legacy-bridge".utf8)
        case .getAssertion:
            let challenge = Data(SHA256.hash(data: payload))
            return try await yubi.performChallengeResponse(challenge: challenge)
        case .makeCredential, .clientPIN:
            throw CTAP2TransportError.commandNotSupported
        }
    }
}

#if canImport(CoreNFC)
private actor CoreNFCCTAP2Coordinator {
    private var session: CoreNFCCTAP2Session?

    func send(command: CTAP2Command, payload: Data) async throws -> Data {
        let activeSession = await currentSession()
        return try await activeSession.transact(command: command, payload: payload)
    }

    func finish(didSucceed: Bool) async {
        guard let session else { return }
        await session.finish(didSucceed: didSucceed)
        self.session = nil
    }

    func updateAlertMessage(_ message: String) async {
        guard let session else { return }
        await session.updateAlertMessage(message)
    }

    private func currentSession() async -> CoreNFCCTAP2Session {
        if let session {
            return session
        }
        let created = await MainActor.run { CoreNFCCTAP2Session() }
        self.session = created
        return created
    }
}
#endif
