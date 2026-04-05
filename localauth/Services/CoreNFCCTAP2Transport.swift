import Foundation
#if canImport(CoreNFC)
import CoreNFC
#endif

#if canImport(CoreNFC)
@MainActor
final class CoreNFCCTAP2Session: NSObject, NFCTagReaderSessionDelegate {
    private enum ConnectedTag {
        case iso7816(any NFCISO7816Tag, preselectedFIDOApplet: Bool)
        case miFare(any NFCMiFareTag)

        var preselectedFIDOApplet: Bool {
            switch self {
            case .iso7816(_, let preselectedFIDOApplet):
                return preselectedFIDOApplet
            case .miFare:
                return false
            }
        }
    }

    private static let fidoAppAID = Data([0xA0, 0x00, 0x00, 0x06, 0x47, 0x2F, 0x00, 0x01])
    private static let shortCommandChunkSize = 240
    private static let fidoCommandClass: UInt8 = 0x80
    private static let chainedCommandClass: UInt8 = 0x90
    private static let fidoMessageInstruction: UInt8 = 0x10
    private static let fidoGetResponseInstruction: UInt8 = 0x11
    private static let maxRetries = 2

    private var session: NFCTagReaderSession?
    private var connectedTag: ConnectedTag?
    private var connectionContinuation: CheckedContinuation<ConnectedTag, Error>?
    private var sessionIdentity: ObjectIdentifier?
    private var connectionSessionIdentity: ObjectIdentifier?
    private var expectedInvalidationSessions: Set<ObjectIdentifier> = []
    private var isAppletSelected = false
    private var lastInvalidationTime: Date = .distantPast

    private func record(_ message: String) {
        Task {
            await HardwareKeyDiagnosticsCenter.shared.record("NFC: \(message)")
        }
    }

    private func recordAsync(_ message: String) async {
        await HardwareKeyDiagnosticsCenter.shared.record("NFC: \(message)")
    }

    func updateAlertMessage(_ message: String) {
        session?.alertMessage = message
        record("弹窗提示: \(message)")
    }

    func transact(command: CTAP2Command, payload: Data) async throws -> Data {
        guard NFCTagReaderSession.readingAvailable else {
            throw CTAP2TransportError.notAvailable
        }
        await recordAsync("开始 \(command.diagnosticLabel)，payload=\(payload.count) bytes")
        var lastError: Error = CTAP2TransportError.operationFailed
        for attempt in 0..<Self.maxRetries {
            do {
                let tag = try await ensureConnectedTag()
                if !isAppletSelected {
                    if !tag.preselectedFIDOApplet {
                        try await selectFIDOApplet(on: tag)
                    }
                    isAppletSelected = true
                }
                let response = try await sendCTAPCommand(command: command, payload: payload, on: tag)
                await recordAsync("\(command.diagnosticLabel) 成功")
                return response
            } catch {
                lastError = Self.normalize(error)
                await recordAsync("\(command.diagnosticLabel) 第 \(attempt + 1) 次失败: \(describe(lastError))")
                guard attempt < Self.maxRetries - 1, Self.isRecoverable(lastError) else {
                    fail(lastError, message: String(localized: "硬件密钥通信失败，请重试。"))
                    throw lastError
                }
                connectedTag = nil
                isAppletSelected = false
                session?.alertMessage = String(localized: "通信中断，正在重试…请保持贴近")
            }
        }
        fail(lastError, message: String(localized: "硬件密钥通信失败，请重试。"))
        throw lastError
    }

    func finish(didSucceed: Bool) {
        record(didSucceed ? "结束会话: 成功" : "结束会话: 失败")
        closeSession(message: didSucceed ? String(localized: "硬件密钥通信完成。") : nil)
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        guard sessionIdentity == ObjectIdentifier(session) else { return }
        record("NFC 会话已激活")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard sessionIdentity == ObjectIdentifier(session) else { return }
        guard connectedTag == nil else { return }
        guard let firstTag = tags.first else {
            fail(CTAP2TransportError.notAvailable, message: String(localized: "未检测到NFC标签。"))
            return
        }
        guard tags.count == 1 else {
            session.alertMessage = String(localized: "检测到多个 NFC 标签，请仅保留一个硬件密钥在感应范围内后重试。")
            session.restartPolling()
            return
        }
        guard let supportedTag = Self.wrap(firstTag) else {
            fail(CTAP2TransportError.notAvailable, message: String(localized: "检测到的NFC标签不支持FIDO通信，请确认贴近的是支持 CTAP2 的硬件密钥。"))
            return
        }
        switch supportedTag {
        case .iso7816(_, let preselectedFIDOApplet):
            record("检测到 ISO7816 标签，预选 FIDO Applet=\(preselectedFIDOApplet)")
        case .miFare:
            record("检测到 MiFare 标签")
        }

        session.connect(to: firstTag) { [weak self] error in
            guard let self else { return }
            if let error {
                // Do not close the session on connect failure; let transact() retry by restarting polling / 连接失败时不要立刻关闭会话，交给 transact() 通过重新轮询来重试
                Task { @MainActor in
                    let cont = self.connectionContinuation
                    self.connectionContinuation = nil
                    self.record("连接标签失败: \(Self.describe(error))")
                    cont?.resume(throwing: Self.normalize(error))
                }
                return
            }
            Task { @MainActor in
                self.record("标签连接成功")
                self.connectedTag = supportedTag
                self.connectionContinuation?.resume(returning: supportedTag)
                self.connectionContinuation = nil
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let invalidatedIdentity = ObjectIdentifier(session)
        let shouldIgnore = expectedInvalidationSessions.remove(invalidatedIdentity) != nil
        let isCurrentSession = sessionIdentity == invalidatedIdentity
        let ownsPendingConnection = connectionSessionIdentity == invalidatedIdentity
        let pendingConnection = ownsPendingConnection ? connectionContinuation : nil
        
        lastInvalidationTime = Date()

        if ownsPendingConnection {
            connectionContinuation = nil
            connectionSessionIdentity = nil
        }
        if isCurrentSession {
            connectedTag = nil
            isAppletSelected = false
            self.session = nil
            sessionIdentity = nil
        }
        record("会话失效: \(Self.describe(error))")
        if shouldIgnore { return }
        pendingConnection?.resume(throwing: Self.normalize(error))
    }

    private func selectFIDOApplet(on tag: ConnectedTag) async throws {
        await recordAsync("发送 SELECT FIDO applet")
        let apdu = try Self.makeAPDU(
            cla: 0x00,
            ins: 0xA4,
            p1: 0x04,
            p2: 0x00,
            data: Self.fidoAppAID,
            le: 256
        )
        let (_, sw1, sw2) = try await send(apdu: apdu, to: tag)
        guard sw1 == 0x90, sw2 == 0x00 else {
            await recordAsync(String(format: "SELECT FIDO applet 失败，SW=%02X%02X", sw1, sw2))
            throw CTAP2TransportError.commandNotSupported
        }
        await recordAsync("SELECT FIDO applet 成功")
    }

    private func sendCTAPCommand(command: CTAP2Command, payload: Data, on tag: ConnectedTag) async throws -> Data {
        let packet = Data([command.rawValue]) + payload
        await recordAsync("发送 CTAP APDU: \(command.diagnosticLabel)，packet=\(packet.count) bytes")
        let (initialData, sw1, sw2) = try await sendChainedCTAPMessage(packet, on: tag)
        let response = try await collectCTAPResponse(initialData: initialData, sw1: sw1, sw2: sw2, on: tag)
        return try stripCTAPStatus(from: response)
    }

    private func sendChainedCTAPMessage(_ packet: Data, on tag: ConnectedTag) async throws -> (Data, UInt8, UInt8) {
        var offset = 0
        let chunkCount = Int(ceil(Double(packet.count) / Double(Self.shortCommandChunkSize)))
        await recordAsync("APDU 分片数 \(max(chunkCount, 1))")
        while packet.count - offset > Self.shortCommandChunkSize {
            let chunk = Data(packet[offset..<(offset + Self.shortCommandChunkSize)])
            let chainedAPDU = try Self.makeShortAPDU(
                cla: Self.chainedCommandClass,
                ins: Self.fidoMessageInstruction,
                data: chunk,
                includeLe: false
            )
            let (_, sw1, sw2) = try await send(apdu: chainedAPDU, to: tag)
            guard sw1 == 0x90, sw2 == 0x00 else {
                await recordAsync(String(format: "链式分片返回 SW=%02X%02X", sw1, sw2))
                throw CTAP2TransportError.operationFailed
            }
            offset += Self.shortCommandChunkSize
        }

        let finalChunk = Data(packet[offset...])
        let finalAPDU = try Self.makeShortAPDU(
            cla: Self.fidoCommandClass,
            ins: Self.fidoMessageInstruction,
            data: finalChunk,
            includeLe: true
        )
        return try await send(apdu: finalAPDU, to: tag)
    }

    private func collectCTAPResponse(initialData: Data, sw1: UInt8, sw2: UInt8, on tag: ConnectedTag) async throws -> Data {
        var collected = initialData
        var currentSW1 = sw1
        var currentSW2 = sw2
        await recordAsync(String(format: "响应开始，SW=%02X%02X", currentSW1, currentSW2))

        while true {
            if currentSW1 == 0x90, currentSW2 == 0x00 {
                return collected
            }

            if currentSW1 == 0x61 {
                let nextLength = currentSW2 == 0x00 ? 256 : Int(currentSW2)
                await recordAsync(String(format: "收到 61xx，继续 GET RESPONSE，长度=%d", nextLength))
                let getResponse = try Self.makeAPDU(
                    cla: Self.fidoCommandClass,
                    ins: 0xC0,
                    data: Data(),
                    le: nextLength
                )
                let (chunk, sw1, sw2) = try await send(apdu: getResponse, to: tag)
                collected.append(chunk)
                currentSW1 = sw1
                currentSW2 = sw2
                await recordAsync(String(format: "GET RESPONSE 返回 SW=%02X%02X", sw1, sw2))
                continue
            }

            if currentSW1 == 0x91, currentSW2 == 0x00 {
                await recordAsync("收到 9100，继续 FIDO GET RESPONSE")
                let getResponse = try Self.makeShortAPDU(
                    cla: Self.fidoCommandClass,
                    ins: Self.fidoGetResponseInstruction,
                    data: Data(),
                    includeLe: true
                )
                let (chunk, sw1, sw2) = try await send(apdu: getResponse, to: tag)
                collected.append(chunk)
                currentSW1 = sw1
                currentSW2 = sw2
                await recordAsync(String(format: "FIDO GET RESPONSE 返回 SW=%02X%02X", sw1, sw2))
                continue
            }

            await recordAsync(String(format: "无法处理的状态字 SW=%02X%02X", currentSW1, currentSW2))
            throw CTAP2TransportError.operationFailed
        }
    }

    private func send(apdu: NFCISO7816APDU, to tag: ConnectedTag) async throws -> (Data, UInt8, UInt8) {
        try await withCheckedThrowingContinuation { cont in
            switch tag {
            case .iso7816(let isoTag, _):
                isoTag.sendCommand(apdu: apdu) { data, sw1, sw2, error in
                    if let error {
                        cont.resume(throwing: Self.normalize(error))
                        return
                    }
                    cont.resume(returning: (data, sw1, sw2))
                }
            case .miFare(let miFareTag):
                miFareTag.sendMiFareISO7816Command(apdu) { data, sw1, sw2, error in
                    if let error {
                        cont.resume(throwing: Self.normalize(error))
                        return
                    }
                    cont.resume(returning: (data, sw1, sw2))
                }
            }
        }
    }

    private func stripCTAPStatus(from data: Data) throws -> Data {
        guard let status = data.first else {
            throw CTAP2TransportError.invalidResponse
        }
        guard status == 0x00 else {
            record(String(format: "CTAP 返回状态 0x%02X", status))
            throw CTAP2TransportError.ctapStatus(status)
        }
        return Data(data.dropFirst())
    }

    private func ensureConnectedTag() async throws -> ConnectedTag {
        if let connectedTag, session != nil {
            return connectedTag
        }

        let timeSinceInvalidation = Date().timeIntervalSince(lastInvalidationTime)
        if timeSinceInvalidation < 1.0 {
            let delay = 1.0 - timeSinceInvalidation
            record("等待 \(String(format: "%.2f", delay)) 秒后再创建新的 NFC 会话")
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try await withCheckedThrowingContinuation { cont in
            connectionContinuation = cont

            // If a session already exists but the tag disconnected, restart polling inside the existing session / 如果会话已存在但标签已断开，就在现有会话内重新开始轮询
            // so the tag can be rediscovered without creating a brand-new session / 这样可以重新发现标签，而无需新建一个全新的会话
            // which would otherwise fail more often or confuse the user / 否则更容易失败，也可能让用户感到困惑
            if let existingSession = session {
                connectionSessionIdentity = sessionIdentity
                record("复用现有会话并重新轮询")
                existingSession.restartPolling()
                return
            }

            guard let createdSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil) else {
                connectionContinuation = nil
                connectionSessionIdentity = nil
                cont.resume(throwing: CTAP2TransportError.notAvailable)
                return
            }
            let identity = ObjectIdentifier(createdSession)
            createdSession.alertMessage = String(localized: "请将支持 FIDO 的硬件密钥贴近手机顶部")
            session = createdSession
            sessionIdentity = identity
            connectionSessionIdentity = identity
            record("创建新的 NFC 会话")
            createdSession.begin()
        }
    }

    private func closeSession(message: String?) {
        guard let session else {
            connectedTag = nil
            isAppletSelected = false
            return
        }
        if let sessionIdentity {
            expectedInvalidationSessions.insert(sessionIdentity)
            if connectionSessionIdentity == sessionIdentity {
                connectionSessionIdentity = nil
            }
        }
        if let message, !message.isEmpty {
            session.alertMessage = message
        }
        lastInvalidationTime = Date()
        session.invalidate()
        connectedTag = nil
        isAppletSelected = false
        self.session = nil
        sessionIdentity = nil
    }

    private func fail(_ error: Error, message: String) {
        let pendingConnection = connectionContinuation
        connectionContinuation = nil
        record("会话失败: \(describe(error))")
        closeSession(message: message)
        pendingConnection?.resume(throwing: error)
    }

    private nonisolated static func wrap(_ tag: NFCTag) -> ConnectedTag? {
        switch tag {
        case .iso7816(let isoTag):
            let selectedAID = isoTag.initialSelectedAID
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return .iso7816(
                isoTag,
                preselectedFIDOApplet: selectedAID == "A0000006472F0001"
            )
        case .miFare(let miFareTag):
            return .miFare(miFareTag)
        case .feliCa, .iso15693:
            return nil
        @unknown default:
            return nil
        }
    }

    private nonisolated static func isRecoverable(_ error: Error) -> Bool {
        guard let transportError = error as? CTAP2TransportError else {
            return true // Unknown errors may be transient NFC glitches / 未知错误可能只是瞬时 NFC 抖动
        }
        switch transportError {
        case .operationFailed, .timeout, .invalidResponse:
            return true
        case .notAvailable, .commandNotSupported:
            return false
        case .ctapStatus(let status):
            // PIN-related errors are not recoverable through simple NFC retries / 与 PIN 相关的错误无法靠简单重试 NFC 来恢复
            switch status {
            case 0x31, 0x32, 0x33, 0x34, 0x36, 0x37: // PIN errors / PIN 错误
                return false
            case 0x2E: // No credentials / 无凭据
                return false
            default:
                return true
            }
        }
    }

    private nonisolated static func normalize(_ error: Error) -> Error {
        if let transportError = error as? CTAP2TransportError {
            return transportError
        }
        return CTAP2TransportError.operationFailed
    }

    private nonisolated static func describe(_ error: Error) -> String {
        if let transportError = error as? CTAP2TransportError {
            return transportError.diagnosticLabel
        }
        return error.localizedDescription
    }

    private func describe(_ error: Error) -> String {
        Self.describe(error)
    }

    private nonisolated static func makeAPDU(
        cla: UInt8,
        ins: UInt8,
        p1: UInt8 = 0x00,
        p2: UInt8 = 0x00,
        data: Data = Data(),
        le: Int? = nil
    ) throws -> NFCISO7816APDU {
        let expectedLength = le ?? -1
        let apdu = NFCISO7816APDU(
            instructionClass: cla,
            instructionCode: ins,
            p1Parameter: p1,
            p2Parameter: p2,
            data: data,
            expectedResponseLength: expectedLength
        )
        return apdu
    }

    private nonisolated static func makeShortAPDU(
        cla: UInt8,
        ins: UInt8,
        p1: UInt8 = 0x00,
        p2: UInt8 = 0x00,
        data: Data,
        includeLe: Bool,
        le: UInt8 = 0x00
    ) throws -> NFCISO7816APDU {
        guard data.count <= 0xFF else {
            throw CTAP2TransportError.operationFailed
        }

        var raw = Data([cla, ins, p1, p2, UInt8(data.count)])
        raw.append(data)
        if includeLe {
            raw.append(le)
        }

        guard let apdu = NFCISO7816APDU(data: raw) else {
            throw CTAP2TransportError.invalidResponse
        }
        return apdu
    }
}
#endif
