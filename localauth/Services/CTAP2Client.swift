import Foundation
import CryptoKit
import CommonCrypto

enum CTAP2ClientError: Error {
    case noTransport
    case unsupportedHMACSecret
    case unsupportedPinProtocol
    case invalidResponse
    case operationFailed
}

extension CTAP2ClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noTransport:
            return String(localized: "未检测到可用的 CTAP2 硬件密钥传输通道。")
        case .unsupportedHMACSecret:
            return String(localized: "当前硬件密钥未声明 hmac-secret 扩展支持。")
        case .unsupportedPinProtocol:
            return String(localized: "当前硬件密钥不支持已实现的 pinUvAuth 协议版本。")
        case .invalidResponse:
            return String(localized: "硬件密钥返回的数据格式无效。")
        case .operationFailed:
            return String(localized: "CTAP2 操作失败。")
        }
    }
}

enum CTAP2Command: UInt8 {
    case makeCredential = 0x01
    case getAssertion = 0x02
    case getInfo = 0x04
    case clientPIN = 0x06
}

protocol CTAP2Transport {
    var transportName: String { get }
    func send(command: CTAP2Command, payload: Data) async throws -> Data
    func finish(didSucceed: Bool) async
    func updateAlertMessage(_ message: String) async
}

extension CTAP2Transport {
    func finish(didSucceed: Bool) async {
    }
    func updateAlertMessage(_ message: String) async {
    }
}

indirect enum CBOR: Equatable {
    case unsigned(UInt64)
    case negative(Int64)
    case bytes(Data)
    case text(String)
    case array([CBOR])
    case map([(CBOR, CBOR)])
    case bool(Bool)
    case null

    static func int(_ value: Int64) -> CBOR {
        value >= 0 ? .unsigned(UInt64(value)) : .negative(value)
    }

    var unsignedValue: UInt64? {
        if case .unsigned(let value) = self { return value }
        return nil
    }

    var intValue: Int64? {
        switch self {
        case .unsigned(let value):
            return Int64(value)
        case .negative(let value):
            return value
        default:
            return nil
        }
    }

    var bytesValue: Data? {
        if case .bytes(let value) = self { return value }
        return nil
    }

    var textValue: String? {
        if case .text(let value) = self { return value }
        return nil
    }

    var arrayValue: [CBOR]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var mapValue: [(CBOR, CBOR)]? {
        if case .map(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    func value(forUnsigned key: UInt64) -> CBOR? {
        guard case .map(let pairs) = self else { return nil }
        return pairs.first(where: { $0.0 == .unsigned(key) })?.1
    }

    func value(forInt key: Int64) -> CBOR? {
        guard case .map(let pairs) = self else { return nil }
        return pairs.first(where: { $0.0 == .int(key) })?.1
    }

    func value(forText key: String) -> CBOR? {
        guard case .map(let pairs) = self else { return nil }
        return pairs.first(where: { $0.0 == .text(key) })?.1
    }

    static func == (lhs: CBOR, rhs: CBOR) -> Bool {
        switch (lhs, rhs) {
        case (.unsigned(let lhsValue), .unsigned(let rhsValue)):
            return lhsValue == rhsValue
        case (.negative(let lhsValue), .negative(let rhsValue)):
            return lhsValue == rhsValue
        case (.bytes(let lhsValue), .bytes(let rhsValue)):
            return lhsValue == rhsValue
        case (.text(let lhsValue), .text(let rhsValue)):
            return lhsValue == rhsValue
        case (.array(let lhsValue), .array(let rhsValue)):
            return lhsValue == rhsValue
        case (.map(let lhsPairs), .map(let rhsPairs)):
            guard lhsPairs.count == rhsPairs.count else { return false }
            return zip(lhsPairs, rhsPairs).allSatisfy { lhsPair, rhsPair in
                lhsPair.0 == rhsPair.0 && lhsPair.1 == rhsPair.1
            }
        case (.bool(let lhsValue), .bool(let rhsValue)):
            return lhsValue == rhsValue
        case (.null, .null):
            return true
        default:
            return false
        }
    }
}

enum CBOREncoder {
    static func encode(_ value: CBOR) -> Data {
        var data = Data()
        append(value, into: &data)
        return data
    }

    private static func append(_ value: CBOR, into data: inout Data) {
        switch value {
        case .unsigned(let number):
            appendMajorType(0, number: number, into: &data)
        case .negative(let number):
            appendMajorType(1, number: UInt64(bitPattern: ~number), into: &data)
        case .bytes(let bytes):
            appendMajorType(2, number: UInt64(bytes.count), into: &data)
            data.append(bytes)
        case .text(let text):
            let utf8 = Data(text.utf8)
            appendMajorType(3, number: UInt64(utf8.count), into: &data)
            data.append(utf8)
        case .array(let array):
            appendMajorType(4, number: UInt64(array.count), into: &data)
            for item in array {
                append(item, into: &data)
            }
        case .map(let pairs):
            appendMajorType(5, number: UInt64(pairs.count), into: &data)
            for (key, value) in pairs {
                append(key, into: &data)
                append(value, into: &data)
            }
        case .bool(let value):
            data.append(value ? 0xF5 : 0xF4)
        case .null:
            data.append(0xF6)
        }
    }

    private static func appendMajorType(_ type: UInt8, number: UInt64, into data: inout Data) {
        if number <= 23 {
            data.append(UInt8((type << 5) | UInt8(number)))
            return
        }
        if number <= UInt64(UInt8.max) {
            data.append(UInt8((type << 5) | 24))
            data.append(UInt8(number))
            return
        }
        if number <= UInt64(UInt16.max) {
            data.append(UInt8((type << 5) | 25))
            var be = UInt16(number).bigEndian
            data.append(Data(bytes: &be, count: 2))
            return
        }
        if number <= UInt64(UInt32.max) {
            data.append(UInt8((type << 5) | 26))
            var be = UInt32(number).bigEndian
            data.append(Data(bytes: &be, count: 4))
            return
        }
        data.append(UInt8((type << 5) | 27))
        var be = number.bigEndian
        data.append(Data(bytes: &be, count: 8))
    }
}

enum CBORDecoder {
    static func decode(_ data: Data) throws -> CBOR {
        var offset = 0
        let value = try decodeValue(data, offset: &offset)
        guard offset == data.count else {
            throw CTAP2ClientError.invalidResponse
        }
        return value
    }

    private static func decodeValue(_ data: Data, offset: inout Int) throws -> CBOR {
        guard offset < data.count else { throw CTAP2ClientError.invalidResponse }
        let initial = data[offset]
        offset += 1

        let majorType = initial >> 5
        let additionalInfo = initial & 0x1F
        let number = try readLength(additionalInfo, data: data, offset: &offset)

        switch majorType {
        case 0:
            return .unsigned(number)
        case 1:
            guard number <= UInt64(Int64.max) else {
                if number == UInt64(bitPattern: Int64.min) {      // 0x8000000000000000
                    return .negative(Int64.min)
                }
                throw CTAP2ClientError.invalidResponse
            }
            return .negative(-1 - Int64(number))
        case 2:
            let end = offset + Int(number)
            guard end <= data.count else { throw CTAP2ClientError.invalidResponse }
            let bytes = Data(data[offset..<end])
            offset = end
            return .bytes(bytes)
        case 3:
            let end = offset + Int(number)
            guard end <= data.count else { throw CTAP2ClientError.invalidResponse }
            let bytes = Data(data[offset..<end])
            offset = end
            guard let string = String(data: bytes, encoding: .utf8) else {
                throw CTAP2ClientError.invalidResponse
            }
            return .text(string)
        case 4:
            var values: [CBOR] = []
            values.reserveCapacity(Int(number))
            for _ in 0..<number {
                values.append(try decodeValue(data, offset: &offset))
            }
            return .array(values)
        case 5:
            var pairs: [(CBOR, CBOR)] = []
            pairs.reserveCapacity(Int(number))
            for _ in 0..<number {
                let key = try decodeValue(data, offset: &offset)
                let value = try decodeValue(data, offset: &offset)
                pairs.append((key, value))
            }
            return .map(pairs)
        case 7:
            switch additionalInfo {
            case 20:
                return .bool(false)
            case 21:
                return .bool(true)
            case 22:
                return .null
            default:
                throw CTAP2ClientError.invalidResponse
            }
        default:
            throw CTAP2ClientError.invalidResponse
        }
    }

    private static func readLength(_ additionalInfo: UInt8, data: Data, offset: inout Int) throws -> UInt64 {
        switch additionalInfo {
        case 0...23:
            return UInt64(additionalInfo)
        case 24:
            guard offset + 1 <= data.count else { throw CTAP2ClientError.invalidResponse }
            defer { offset += 1 }
            return UInt64(data[offset])
        case 25:
            guard offset + 2 <= data.count else { throw CTAP2ClientError.invalidResponse }
            let value = readUInt16BE(data[offset..<offset + 2])
            offset += 2
            return UInt64(value)
        case 26:
            guard offset + 4 <= data.count else { throw CTAP2ClientError.invalidResponse }
            let value = readUInt32BE(data[offset..<offset + 4])
            offset += 4
            return UInt64(value)
        case 27:
            guard offset + 8 <= data.count else { throw CTAP2ClientError.invalidResponse }
            let value = readUInt64BE(data[offset..<offset + 8])
            offset += 8
            return value
        default:
            throw CTAP2ClientError.invalidResponse
        }
    }

    private static func readUInt16BE(_ bytes: Data.SubSequence) -> UInt16 {
        bytes.reduce(UInt16(0)) { (partial, byte) in
            (partial << 8) | UInt16(byte)
        }
    }

    private static func readUInt32BE(_ bytes: Data.SubSequence) -> UInt32 {
        bytes.reduce(UInt32(0)) { (partial, byte) in
            (partial << 8) | UInt32(byte)
        }
    }

    private static func readUInt64BE(_ bytes: Data.SubSequence) -> UInt64 {
        bytes.reduce(UInt64(0)) { (partial, byte) in
            (partial << 8) | UInt64(byte)
        }
    }
}

struct CTAP2Client {
    private enum ClientPINPermission: UInt8 {
        case makeCredential = 0x01
        case getAssertion = 0x02
    }

    private enum PINTokenMode {
        case automatic
        case legacyOnly
    }

    struct AuthenticatorInfo {
        let versions: [String]
        let extensions: [String]
        let options: [String: Bool]
        let pinProtocols: [UInt64]

        var supportsHMACSecret: Bool {
            extensions.contains("hmac-secret")
        }

        var supportsPinProtocol1: Bool {
            pinProtocols.contains(1)
        }
    }

    struct HMACSecretRegistration {
        let credentialID: Data
        let hmacOutput: Data
    }

    private struct SelectedTransport {
        let transport: any CTAP2Transport
        let info: AuthenticatorInfo
    }

    private struct ClientPINState {
        let protocolVersion: UInt64
        let platformKey: P256.KeyAgreement.PrivateKey
        let sharedSecret: Data
    }

    let transports: [any CTAP2Transport]

    private let rpId = "local.localauth"
    private let rpName = "LocalAuth"

    func probeInfo() async throws -> AuthenticatorInfo {
        await record("开始探测支持 hmac-secret 的传输")
        let selected = try await selectCapableTransport()
        await record("已选中传输 \(selected.transport.transportName)")
        await selected.transport.finish(didSucceed: true)
        return selected.info
    }

    func registerHMACSecretCredential(challenge: Data, pin: String?) async throws -> HMACSecretRegistration {
        let selected = try await selectCapableTransport()
        do {
            await record("注册流程使用传输 \(selected.transport.transportName)")
            await selected.transport.updateAlertMessage(String(localized: "正在创建凭据，请保持贴近…"))
            let makeCredentialHash = Data(SHA256.hash(data: Data("make-credential".utf8) + challenge))
            let credentialID = try await makeCredentialWithFallback(
                using: selected.transport,
                pin: pin,
                info: selected.info,
                clientDataHash: makeCredentialHash
            )

            await selected.transport.updateAlertMessage(String(localized: "正在再次验证 PIN，请保持贴近…"))
            let assertionHash = Data(SHA256.hash(data: Data("get-assertion".utf8) + challenge))
            let hmacOutput = try await getAssertionHMACSecretWithFallback(
                using: selected.transport,
                pin: pin,
                info: selected.info,
                credentialID: credentialID,
                salt: challenge,
                clientDataHash: assertionHash
            )

            await selected.transport.finish(didSucceed: true)
            return HMACSecretRegistration(credentialID: credentialID, hmacOutput: hmacOutput)
        } catch {
            await record("注册流程失败: \(describe(error))")
            await selected.transport.finish(didSucceed: false)
            throw error
        }
    }

    private func makeCredentialWithFallback(
        using transport: any CTAP2Transport,
        pin: String?,
        info: AuthenticatorInfo,
        clientDataHash: Data
    ) async throws -> Data {
        do {
            await record("准备执行 makeCredential")
            await transport.updateAlertMessage(String(localized: "正在验证 PIN…"))
            let makeCredentialAuth = try await acquirePINAuthorization(
                using: transport,
                pin: pin,
                info: info,
                permission: .makeCredential
            )
            return try await makeCredential(
                using: transport,
                clientDataHash: clientDataHash,
                pinToken: makeCredentialAuth.token,
                pinState: makeCredentialAuth.state
            )
        } catch {
            guard shouldRetryLegacyPINFlow(after: error) else {
                throw error
            }

            await record("makeCredential 遇到 \(describe(error))，回退到 legacy PIN token")
            await transport.updateAlertMessage(String(localized: "正在重试兼容模式，请保持贴近…"))
            let makeCredentialAuth = try await acquirePINAuthorization(
                using: transport,
                pin: pin,
                info: info,
                permission: .makeCredential,
                mode: .legacyOnly
            )
            return try await makeCredential(
                using: transport,
                clientDataHash: clientDataHash,
                pinToken: makeCredentialAuth.token,
                pinState: makeCredentialAuth.state
            )
        }
    }

    func requestHMACSecret(challenge: Data, credentialID: Data, pin: String?) async throws -> Data {
        let selected = try await selectCapableTransport()
        do {
            await record("解锁流程使用传输 \(selected.transport.transportName)")
            let output = try await requestHMACSecret(
                challenge: challenge,
                credentialID: credentialID,
                pin: pin,
                selected: selected,
                mode: .automatic
            )
            await selected.transport.finish(didSucceed: true)
            return output
        } catch {
            if shouldRetryLegacyPINFlow(after: error) {
                do {
                    let output = try await requestHMACSecret(
                        challenge: challenge,
                        credentialID: credentialID,
                        pin: pin,
                        selected: selected,
                        mode: .legacyOnly
                    )
                    await selected.transport.finish(didSucceed: true)
                    return output
                } catch {
                    await selected.transport.finish(didSucceed: false)
                    throw error
                }
            }
            await selected.transport.finish(didSucceed: false)
            throw error
        }
    }

    private func selectCapableTransport() async throws -> SelectedTransport {
        var discoveredTransport = false
        var lastError: Error?
        var firstNonAvailabilityError: Error?
        for transport in transports {
            do {
                await record("尝试传输 \(transport.transportName) -> getInfo")
                let payload = try await transport.send(command: .getInfo, payload: Data())
                discoveredTransport = true
                let info = try decodeInfo(from: payload)
                guard info.supportsHMACSecret else {
                    await record("传输 \(transport.transportName) 未声明 hmac-secret")
                    await transport.finish(didSucceed: false)
                    continue
                }
                await record("传输 \(transport.transportName) 可用")
                return SelectedTransport(transport: transport, info: info)
            } catch {
                lastError = error
                if firstNonAvailabilityError == nil, !isAvailabilityError(error) {
                    firstNonAvailabilityError = error
                }
                await record("传输 \(transport.transportName) 失败: \(describe(error))")
                await transport.finish(didSucceed: false)
                try? await Task.sleep(nanoseconds: 300_000_000)
                continue
            }
        }
        if !discoveredTransport {
            if let firstNonAvailabilityError {
                throw firstNonAvailabilityError
            }
            if let lastError {
                throw lastError
            }
        }
        throw discoveredTransport ? CTAP2ClientError.unsupportedHMACSecret : CTAP2ClientError.noTransport
    }

    private func isAvailabilityError(_ error: Error) -> Bool {
        if let transportError = error as? CTAP2TransportError,
           case .notAvailable = transportError {
            return true
        }
        if let clientError = error as? CTAP2ClientError,
           case .noTransport = clientError {
            return true
        }
        return false
    }

    private func decodeInfo(from payload: Data) throws -> AuthenticatorInfo {
        let decoded = try CBORDecoder.decode(payload)
        let versions = decoded.value(forUnsigned: 0x01)?.arrayValue?.compactMap(\.textValue) ?? []
        let extensions = decoded.value(forUnsigned: 0x02)?.arrayValue?.compactMap(\.textValue) ?? []
        let optionsPairs = decoded.value(forUnsigned: 0x04)?.mapValue ?? []
        var options: [String: Bool] = [:]
        for (key, value) in optionsPairs {
            if let key = key.textValue, let value = value.boolValue {
                options[key] = value
            }
        }
        let pinProtocols = decoded.value(forUnsigned: 0x06)?.arrayValue?.compactMap(\.unsignedValue) ?? []
        return AuthenticatorInfo(
            versions: versions,
            extensions: extensions,
            options: options,
            pinProtocols: pinProtocols
        )
    }

    private func getPINState(using transport: any CTAP2Transport, info: AuthenticatorInfo) async throws -> ClientPINState {
        guard info.supportsPinProtocol1 else {
            throw CTAP2ClientError.unsupportedPinProtocol
        }

        await record("执行 clientPIN(getKeyAgreement)")
        let request = CBOREncoder.encode(.map([
            (.unsigned(0x01), .unsigned(1)),
            (.unsigned(0x02), .unsigned(0x02)),
        ]))
        let response = try await transport.send(command: .clientPIN, payload: request)
        let decoded = try CBORDecoder.decode(response)
        guard let authenticatorKey = decoded.value(forUnsigned: 0x01) else {
            throw CTAP2ClientError.invalidResponse
        }

        let platformKey = P256.KeyAgreement.PrivateKey()
        let sharedSecret = try deriveSharedSecret(
            authenticatorKeyAgreement: authenticatorKey,
            platformKey: platformKey
        )
        return ClientPINState(protocolVersion: 1, platformKey: platformKey, sharedSecret: sharedSecret)
    }

    private func deriveSharedSecret(
        authenticatorKeyAgreement: CBOR,
        platformKey: P256.KeyAgreement.PrivateKey
    ) throws -> Data {
        guard let x = authenticatorKeyAgreement.value(forInt: -2)?.bytesValue,
              let y = authenticatorKeyAgreement.value(forInt: -3)?.bytesValue else {
            throw CTAP2ClientError.invalidResponse
        }
        let publicKeyData = Data([0x04]) + x + y
        let authenticatorPublicKey = try P256.KeyAgreement.PublicKey(x963Representation: publicKeyData)
        let sharedSecret = try platformKey.sharedSecretFromKeyAgreement(with: authenticatorPublicKey)
        let secretData = sharedSecret.withUnsafeBytes { Data($0) }
        return Data(SHA256.hash(data: secretData))
    }

    private func acquirePINAuthorization(
        using transport: any CTAP2Transport,
        pin: String?,
        info: AuthenticatorInfo,
        permission: ClientPINPermission,
        mode: PINTokenMode = .automatic
    ) async throws -> (state: ClientPINState, token: Data?) {
        let pinState = try await getPINState(using: transport, info: info)
        let pinToken = try await getPINTokenIfNeeded(
            using: transport,
            pin: pin,
            info: info,
            pinState: pinState,
            permission: permission,
            mode: mode
        )
        return (pinState, pinToken)
    }

    private func getPINTokenIfNeeded(
        using transport: any CTAP2Transport,
        pin: String?,
        info: AuthenticatorInfo,
        pinState: ClientPINState,
        permission: ClientPINPermission,
        mode: PINTokenMode = .automatic
    ) async throws -> Data? {
        guard let pin = pin?.trimmingCharacters(in: .whitespacesAndNewlines), !pin.isEmpty else {
            await record("跳过 PIN token: 未提供 PIN")
            return nil
        }
        guard info.options["clientPin"] == true || info.options["pinUvAuthToken"] == true else {
            await record("跳过 PIN token: 设备未启用 clientPin/pinUvAuthToken")
            return nil
        }

        let pinHash = Data(SHA256.hash(data: Data(pin.utf8))).prefix(16)
        let pinHashEnc = try aesCBC(input: Data(pinHash), key: pinState.sharedSecret, operation: CCOperation(kCCEncrypt))
        let permissionBits = permission.rawValue

        let canUsePermissionScopedToken =
            mode == .automatic &&
            info.options["pinUvAuthToken"] == true &&
            info.options["noMcGaPermissionsWithClientPin"] != true

        if canUsePermissionScopedToken {
            await record("执行 clientPIN(getPinUvAuthTokenUsingPinWithPermissions) for \(permissionName(permission))")
            let requestMap: [(CBOR, CBOR)] = [
                (.unsigned(0x01), .unsigned(pinState.protocolVersion)),
                (.unsigned(0x02), .unsigned(0x09)),
                (.unsigned(0x03), encodeCOSEPublicKey(for: pinState.platformKey.publicKey)),
                (.unsigned(0x06), .bytes(pinHashEnc)),
                (.unsigned(0x09), .unsigned(UInt64(permissionBits))),
                (.unsigned(0x0A), .text(rpId)),
            ]
            do {
                return try await requestPINToken(using: transport, requestMap: requestMap, pinState: pinState)
            } catch {
                if !shouldRetryLegacyPINToken(after: error) {
                    throw error
                }
                await record("permission-scoped PIN token 失败: \(describe(error))，切换到 legacy")
            }
        }

        await record("执行 clientPIN(getPinToken legacy) for \(permissionName(permission))")
        let requestMap: [(CBOR, CBOR)] = [
            (.unsigned(0x01), .unsigned(pinState.protocolVersion)),
            (.unsigned(0x02), .unsigned(0x05)),
            (.unsigned(0x03), encodeCOSEPublicKey(for: pinState.platformKey.publicKey)),
            (.unsigned(0x06), .bytes(pinHashEnc)),
        ]
        return try await requestPINToken(using: transport, requestMap: requestMap, pinState: pinState)
    }

    private func requestHMACSecret(
        challenge: Data,
        credentialID: Data,
        pin: String?,
        selected: SelectedTransport,
        mode: PINTokenMode
    ) async throws -> Data {
        await selected.transport.updateAlertMessage(String(localized: "正在验证 PIN…"))
        await record("准备执行 getAssertion")
        let assertionAuth = try await acquirePINAuthorization(
            using: selected.transport,
            pin: pin,
            info: selected.info,
            permission: .getAssertion,
            mode: mode
        )
        await selected.transport.updateAlertMessage(String(localized: "正在读取密钥，请保持贴近…"))
        let clientDataHash = Data(SHA256.hash(data: Data("get-assertion".utf8) + challenge))
        return try await getAssertionHMACSecret(
            using: selected.transport,
            credentialID: credentialID,
            salt: challenge,
            clientDataHash: clientDataHash,
            pinToken: assertionAuth.token,
            pinState: assertionAuth.state,
            requireUserPresence: false
        )
    }

    private func getAssertionHMACSecretWithFallback(
        using transport: any CTAP2Transport,
        pin: String?,
        info: AuthenticatorInfo,
        credentialID: Data,
        salt: Data,
        clientDataHash: Data
    ) async throws -> Data {
        do {
            await record("准备执行 getAssertion")
            await transport.updateAlertMessage(String(localized: "正在验证凭据，请保持贴近…"))
            let getAssertionAuth = try await acquirePINAuthorization(
                using: transport,
                pin: pin,
                info: info,
                permission: .getAssertion
            )
            return try await getAssertionHMACSecret(
                using: transport,
                credentialID: credentialID,
                salt: salt,
                clientDataHash: clientDataHash,
                pinToken: getAssertionAuth.token,
                pinState: getAssertionAuth.state,
                requireUserPresence: false
            )
        } catch {
            guard shouldRetryLegacyPINFlow(after: error) else {
                throw error
            }

            await record("getAssertion 遇到 \(describe(error))，回退到 legacy PIN token")
            await transport.updateAlertMessage(String(localized: "正在重试兼容模式，请保持贴近…"))
            let getAssertionAuth = try await acquirePINAuthorization(
                using: transport,
                pin: pin,
                info: info,
                permission: .getAssertion,
                mode: .legacyOnly
            )
            return try await getAssertionHMACSecret(
                using: transport,
                credentialID: credentialID,
                salt: salt,
                clientDataHash: clientDataHash,
                pinToken: getAssertionAuth.token,
                pinState: getAssertionAuth.state,
                requireUserPresence: false
            )
        }
    }

    private func makeCredential(
        using transport: any CTAP2Transport,
        clientDataHash: Data,
        pinToken: Data?,
        pinState: ClientPINState
    ) async throws -> Data {
        await record("发送 makeCredential")
        let userID = try EncryptionService.generateRandomBytes(32)
        var map: [(CBOR, CBOR)] = [
            (.unsigned(0x01), .bytes(clientDataHash)),
            (.unsigned(0x02), .map([
                (.text("id"), .text(rpId)),
                (.text("name"), .text(rpName)),
            ])),
            (.unsigned(0x03), .map([
                (.text("id"), .bytes(userID)),
                (.text("name"), .text("localauth-user")),
                (.text("displayName"), .text("LocalAuth User")),
            ])),
            (.unsigned(0x04), .array([
                .map([
                    (.text("type"), .text("public-key")),
                    (.text("alg"), .int(-7)),
                ]),
            ])),
            (.unsigned(0x06), .map([
                (.text("hmac-secret"), .bool(true)),
            ])),
            (.unsigned(0x07), .map([
                (.text("rk"), .bool(false)),
            ])),
        ]

        if let pinToken {
            map.append((.unsigned(0x08), .bytes(pinUvAuthParam(pinToken: pinToken, clientDataHash: clientDataHash))))
            map.append((.unsigned(0x09), .unsigned(pinState.protocolVersion)))
        }

        let payload = CBOREncoder.encode(.map(map))
        let response = try await transport.send(command: .makeCredential, payload: payload)
        let decoded = try CBORDecoder.decode(response)
        guard let authData = decoded.value(forUnsigned: 0x02)?.bytesValue else {
            throw CTAP2ClientError.invalidResponse
        }
        await record("makeCredential 成功")
        return try parseCredentialID(fromMakeCredentialAuthData: authData)
    }

    private func getAssertionHMACSecret(
        using transport: any CTAP2Transport,
        credentialID: Data,
        salt: Data,
        clientDataHash: Data,
        pinToken: Data?,
        pinState: ClientPINState,
        requireUserPresence: Bool
    ) async throws -> Data {
        await record("发送 getAssertion")
        let salt32 = normalizedSalt(salt)
        let saltEnc = try aesCBC(input: salt32, key: pinState.sharedSecret, operation: CCOperation(kCCEncrypt))
        let saltAuth = Data(hmacSHA256(key: pinState.sharedSecret, message: saltEnc).prefix(16))

        var map: [(CBOR, CBOR)] = [
            (.unsigned(0x01), .text(rpId)),
            (.unsigned(0x02), .bytes(clientDataHash)),
            (.unsigned(0x03), .array([
                .map([
                    (.text("type"), .text("public-key")),
                    (.text("id"), .bytes(credentialID)),
                ]),
            ])),
            (.unsigned(0x04), .map([
                (.text("hmac-secret"), .map([
                    (.unsigned(0x01), encodeCOSEPublicKey(for: pinState.platformKey.publicKey)),
                    (.unsigned(0x02), .bytes(saltEnc)),
                    (.unsigned(0x03), .bytes(saltAuth)),
                    (.unsigned(0x04), .unsigned(pinState.protocolVersion)),
                ])),
            ])),
        ]

        if requireUserPresence {
            map.append((.unsigned(0x05), .map([
                (.text("up"), .bool(true)),
            ])))
        }

        if let pinToken {
            map.append((.unsigned(0x06), .bytes(pinUvAuthParam(pinToken: pinToken, clientDataHash: clientDataHash))))
            map.append((.unsigned(0x07), .unsigned(pinState.protocolVersion)))
        }

        let payload = CBOREncoder.encode(.map(map))
        let response = try await transport.send(command: .getAssertion, payload: payload)
        let decoded = try CBORDecoder.decode(response)
        guard let authData = decoded.value(forUnsigned: 0x02)?.bytesValue else {
            throw CTAP2ClientError.invalidResponse
        }
        let encryptedOutput = try parseEncryptedHMACSecret(fromAssertionAuthData: authData)
        let plaintext = try aesCBC(input: encryptedOutput, key: pinState.sharedSecret, operation: CCOperation(kCCDecrypt))
        guard plaintext.count >= 32 else {
            throw CTAP2ClientError.invalidResponse
        }
        await record("getAssertion 成功")
        return Data(plaintext.prefix(32))
    }

    private func requestPINToken(
        using transport: any CTAP2Transport,
        requestMap: [(CBOR, CBOR)],
        pinState: ClientPINState
    ) async throws -> Data {
        let request = CBOREncoder.encode(.map(requestMap))
        let getResponse = try await transport.send(command: .clientPIN, payload: request)
        let getDecoded = try CBORDecoder.decode(getResponse)
        guard let encryptedToken = getDecoded.value(forUnsigned: 0x02)?.bytesValue else {
            throw CTAP2ClientError.invalidResponse
        }
        let token = try aesCBC(input: encryptedToken, key: pinState.sharedSecret, operation: CCOperation(kCCDecrypt))
        guard token.count == 16 || token.count == 32 else {
            throw CTAP2ClientError.invalidResponse
        }
        await record("clientPIN token 已返回，长度 \(token.count)")
        return token
    }

    private func shouldRetryLegacyPINToken(after error: Error) -> Bool {
        guard let transportError = error as? CTAP2TransportError else {
            return false
        }

        switch transportError {
        case .commandNotSupported:
            return true
        case .ctapStatus(let status):
            switch status {
            case 0x31, 0x32, 0x34, 0x36, 0x37:
                return false
            default:
                return true
            }
        default:
            return false
        }
    }

    private func shouldRetryLegacyPINFlow(after error: Error) -> Bool {
        guard let transportError = error as? CTAP2TransportError else {
            return false
        }

        switch transportError {
        case .ctapStatus(let status):
            return status == 0x33
        default:
            return false
        }
    }

    private func permissionName(_ permission: ClientPINPermission) -> String {
        switch permission {
        case .makeCredential:
            return "makeCredential"
        case .getAssertion:
            return "getAssertion"
        }
    }

    private func record(_ message: String) async {
        await HardwareKeyDiagnosticsCenter.shared.record("CTAP2: \(message)")
    }

    private func describe(_ error: Error) -> String {
        if let transportError = error as? CTAP2TransportError {
            return transportError.diagnosticLabel
        }
        if let clientError = error as? CTAP2ClientError {
            switch clientError {
            case .noTransport:
                return "noTransport"
            case .unsupportedHMACSecret:
                return "unsupportedHMACSecret"
            case .unsupportedPinProtocol:
                return "unsupportedPinProtocol"
            case .invalidResponse:
                return "invalidResponse"
            case .operationFailed:
                return "operationFailed"
            }
        }
        return error.localizedDescription
    }

    private func parseCredentialID(fromMakeCredentialAuthData authData: Data) throws -> Data {
        guard authData.count >= 55 else {
            throw CTAP2ClientError.invalidResponse
        }
        let flags = authData[32]
        guard flags & 0x40 != 0 else {
            throw CTAP2ClientError.invalidResponse
        }
        let credentialLengthRange = 53..<55
        let credentialLength = authData[credentialLengthRange].reduce(UInt16(0)) { partial, byte in
            (partial << 8) | UInt16(byte)
        }
        let credentialStart = 55
        let credentialEnd = credentialStart + Int(credentialLength)
        guard credentialEnd <= authData.count else {
            throw CTAP2ClientError.invalidResponse
        }
        return Data(authData[credentialStart..<credentialEnd])
    }

    private func parseEncryptedHMACSecret(fromAssertionAuthData authData: Data) throws -> Data {
        guard authData.count >= 37 else {
            throw CTAP2ClientError.invalidResponse
        }
        let flags = authData[32]
        guard flags & 0x80 != 0 else {
            throw CTAP2ClientError.invalidResponse
        }
        let extensionData = Data(authData.dropFirst(37))
        let decodedExtensions = try CBORDecoder.decode(extensionData)
        guard let encryptedOutput = decodedExtensions.value(forText: "hmac-secret")?.bytesValue else {
            throw CTAP2ClientError.invalidResponse
        }
        return encryptedOutput
    }

    private func normalizedSalt(_ salt: Data) -> Data {
        if salt.count == 32 {
            return salt
        }
        if salt.count > 32 {
            return Data(salt.prefix(32))
        }
        var normalized = salt
        normalized.append(Data(repeating: 0, count: 32 - salt.count))
        return normalized
    }

    private func encodeCOSEPublicKey(for publicKey: P256.KeyAgreement.PublicKey) -> CBOR {
        let x963 = publicKey.x963Representation
        let x = Data(x963[1...32])
        let y = Data(x963[33...64])
        return .map([
            (.int(1), .unsigned(2)),
            (.int(3), .int(-25)),
            (.int(-1), .unsigned(1)),
            (.int(-2), .bytes(x)),
            (.int(-3), .bytes(y)),
        ])
    }

    private func pinUvAuthParam(pinToken: Data, clientDataHash: Data) -> Data {
        Data(hmacSHA256(key: pinToken, message: clientDataHash).prefix(16))
    }

    private func hmacSHA256(key: Data, message: Data) -> Data {
        var output = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBytes in
            message.withUnsafeBytes { messageBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress,
                    key.count,
                    messageBytes.baseAddress,
                    message.count,
                    &output
                )
            }
        }
        return Data(output)
    }

    private func aesCBC(input: Data, key: Data, operation: CCOperation) throws -> Data {
        guard key.count >= kCCKeySizeAES256, input.count.isMultiple(of: kCCBlockSizeAES128) else {
            throw CTAP2ClientError.invalidResponse
        }

        let keyData = Data(key.prefix(kCCKeySizeAES256))
        let iv = Data(repeating: 0, count: kCCBlockSizeAES128)
        var output = Data(count: input.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        var outputLength = 0

        let status = output.withUnsafeMutableBytes { outputBytes in
            input.withUnsafeBytes { inputBytes in
                keyData.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(0),
                            keyBytes.baseAddress,
                            keyData.count,
                            ivBytes.baseAddress,
                            inputBytes.baseAddress,
                            input.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw CTAP2ClientError.operationFailed
        }
        output.removeSubrange(outputLength..<output.count)
        return output
    }
}
