import Foundation
import CryptoKit
import DeviceCheck
import Security

enum TravelVaultAppAttestService {
    static let keyIDHeaderName = "X-LocalAuth-AppAttest-KeyID"
    static let challengeHeaderName = "X-LocalAuth-AppAttest-Challenge"
    static let assertionHeaderName = "X-LocalAuth-AppAttest-Assertion"

    private static let keyIDDefaultsKey = "TravelVaultAppAttestKeyID"
    private static let registrationVersionDefaultsKey = "TravelVaultAppAttestRegistrationVersion"
    private static let registrationVersion = 2

    static func applyAuthorizationHeaders(
        to request: inout URLRequest,
        session: URLSession
    ) async throws {
        guard DCAppAttestService.shared.isSupported else {
            throw TravelVaultError.appAttestNotSupported
        }

        do {
            let proof = try await prepareAuthorizationProof(
                for: request,
                session: session,
                forceFreshRegistration: false
            )
            apply(proof: proof, to: &request)
        } catch {
            guard shouldRetryAuthorizationPreparation(for: error) else {
                throw error
            }

            resetLocalRegistration()
            let proof = try await prepareAuthorizationProof(
                for: request,
                session: session,
                forceFreshRegistration: true
            )
            apply(proof: proof, to: &request)
        }
    }

    static func resetLocalRegistration() {
        deleteKeychainItem(forKey: keyIDDefaultsKey)
        deleteKeychainItem(forKey: registrationVersionDefaultsKey)
        UserDefaults.standard.removeObject(forKey: keyIDDefaultsKey)
        UserDefaults.standard.removeObject(forKey: registrationVersionDefaultsKey)
    }

    private static func prepareAuthorizationProof(
        for request: URLRequest,
        session: URLSession,
        forceFreshRegistration: Bool
    ) async throws -> TravelVaultAuthorizationProof {
        let keyID = try await ensureRegisteredKeyID(
            session: session,
            forceFreshRegistration: forceFreshRegistration
        )
        let challenge = try await fetchChallenge(session: session)
        let payload = try canonicalAssertionPayload(for: request, challenge: challenge)
        let assertion = try await generateAssertion(for: keyID, payload: payload)
        return TravelVaultAuthorizationProof(
            keyID: keyID,
            challenge: challenge,
            assertion: assertion
        )
    }

    private static func apply(proof: TravelVaultAuthorizationProof, to request: inout URLRequest) {
        request.setValue(proof.keyID, forHTTPHeaderField: keyIDHeaderName)
        request.setValue(proof.challenge, forHTTPHeaderField: challengeHeaderName)
        request.setValue(proof.assertion.base64EncodedString(), forHTTPHeaderField: assertionHeaderName)
    }

    private static func ensureRegisteredKeyID(
        session: URLSession,
        forceFreshRegistration: Bool
    ) async throws -> String {
        if forceFreshRegistration || registrationStateNeedsReset {
            resetLocalRegistration()
        }

        if let storedKeyID = storedKeyID {
            return storedKeyID
        }

        return try await registerFreshKey(session: session, remainingAttempts: 2)
    }

    private static func registerFreshKey(session: URLSession, remainingAttempts: Int) async throws -> String {
        precondition(remainingAttempts > 0)

        let service = DCAppAttestService.shared
        let keyID = try await service.generateKey()
        let challenge = try await fetchChallenge(session: session)
        let challengeData = try decodeChallengeData(challenge)
        let clientDataHash = Data(SHA256.hash(data: challengeData))
        let attestation = try await service.attestKey(keyID, clientDataHash: clientDataHash)
        do {
            let registrationToken = try await verifyDeviceAttestationWithRemoteVerifier(
                keyID: keyID,
                challenge: challenge,
                attestation: attestation,
                session: session
            )
            try await registerVerifiedDevice(
                with: registrationToken,
                session: session
            )
            persistRegisteredKeyID(keyID)
            return keyID
        } catch let error as TravelVaultError {
            if remainingAttempts > 1, shouldRetryDeviceRegistration(for: error) {
                resetLocalRegistration()
                return try await registerFreshKey(session: session, remainingAttempts: remainingAttempts - 1)
            }
            throw error
        } catch {
            if remainingAttempts > 1 {
                resetLocalRegistration()
                return try await registerFreshKey(session: session, remainingAttempts: remainingAttempts - 1)
            }
            throw error
        }
    }

    private static func fetchChallenge(session: URLSession) async throws -> String {
        var request = try makeRemoteRequest(
            baseURLString: TravelVaultRemoteConfig.baseURLString,
            path: TravelVaultRemoteConfig.deviceChallengePath,
            method: "GET"
        )
        applyConfiguredHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TravelVaultError.invalidRemoteResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapRemoteFailure(data: data, statusCode: httpResponse.statusCode, defaultError: .deviceChallengeFailed)
        }

        let decoded = try JSONDecoder.travelVaultDecoder.decode(DeviceChallengeResponse.self, from: data)
        guard !decoded.challenge.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TravelVaultError.invalidRemoteResponse
        }
        return decoded.challenge
    }

    private static func generateAssertion(for keyID: String, payload: Data) async throws -> Data {
        let hash = Data(SHA256.hash(data: payload))
        return try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: hash)
    }

    private static func verifyDeviceAttestationWithRemoteVerifier(
        keyID: String,
        challenge: String,
        attestation: Data,
        session: URLSession
    ) async throws -> String {
        let trimmedBaseURL = TravelVaultRemoteConfig.deviceAttestBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else {
            throw TravelVaultError.remoteNotConfigured
        }

        var request = try makeRemoteRequest(
            baseURLString: trimmedBaseURL,
            path: TravelVaultRemoteConfig.deviceAttestPath,
            method: "POST"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyConfiguredHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(
            DeviceAttestRequest(
                keyID: keyID,
                challenge: challenge,
                attestation: attestation.base64EncodedString()
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TravelVaultError.invalidRemoteResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapRemoteFailure(data: data, statusCode: httpResponse.statusCode, defaultError: .deviceAttestationFailed)
        }

        let decoded = try JSONDecoder().decode(DeviceAttestResponse.self, from: data)
        let token = decoded.registrationToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw TravelVaultError.invalidRemoteResponse
        }
        return token
    }

    private static func registerVerifiedDevice(
        with registrationToken: String,
        session: URLSession
    ) async throws {
        var request = try makeRemoteRequest(
            baseURLString: TravelVaultRemoteConfig.baseURLString,
            path: TravelVaultRemoteConfig.deviceRegisterPath,
            method: "POST"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyConfiguredHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(
            DeviceRegisterRequest(registrationToken: registrationToken)
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TravelVaultError.invalidRemoteResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapRemoteFailure(data: data, statusCode: httpResponse.statusCode, defaultError: .deviceAttestationFailed)
        }
    }

    private static func canonicalAssertionPayload(for request: URLRequest, challenge: String) throws -> Data {
        let method = (request.httpMethod ?? "GET").uppercased()
        let path = request.url?.path ?? "/"
        let bodyHash = sha256Hex(for: request.httpBody ?? Data())
        let canonical = [method, path, challenge, bodyHash].joined(separator: "\n")
        guard let data = canonical.data(using: .utf8) else {
            throw TravelVaultError.invalidRemoteResponse
        }
        return data
    }

    private static func makeRemoteRequest(baseURLString: String, path: String, method: String) throws -> URLRequest {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let baseURL = URL(string: trimmed),
              let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw TravelVaultError.remoteNotConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        return request
    }

    private static func applyConfiguredHeaders(to request: inout URLRequest) {
        for (key, value) in TravelVaultRemoteConfig.requestHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private static var storedKeyID: String? {
        if let legacyValue = UserDefaults.standard.string(forKey: keyIDDefaultsKey),
           !legacyValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveKeychainString(legacyValue, forKey: keyIDDefaultsKey)
            let legacyVersion = UserDefaults.standard.integer(forKey: registrationVersionDefaultsKey)
            if legacyVersion > 0 {
                saveKeychainString(String(legacyVersion), forKey: registrationVersionDefaultsKey)
            }
            UserDefaults.standard.removeObject(forKey: keyIDDefaultsKey)
            UserDefaults.standard.removeObject(forKey: registrationVersionDefaultsKey)
            return legacyValue
        }

        guard let value = loadKeychainString(forKey: keyIDDefaultsKey) else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }

    private static var registrationStateNeedsReset: Bool {
        guard let versionString = loadKeychainString(forKey: registrationVersionDefaultsKey),
              let version = Int(versionString) else {
            return true
        }
        return version != registrationVersion
    }

    private static func persistRegisteredKeyID(_ keyID: String) {
        saveKeychainString(keyID, forKey: keyIDDefaultsKey)
        saveKeychainString(String(registrationVersion), forKey: registrationVersionDefaultsKey)
    }

    private static func sha256Hex(for data: Data) -> String {
        Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }

    private static func decodeChallengeData(_ challenge: String) throws -> Data {
        let trimmedChallenge = challenge.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChallenge.isEmpty else {
            throw TravelVaultError.invalidRemoteResponse
        }

        var base64 = trimmedChallenge
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let decoded = Data(base64Encoded: base64), !decoded.isEmpty else {
            throw TravelVaultError.invalidRemoteResponse
        }
        return decoded
    }

    private static func shouldRetryDeviceRegistration(for error: TravelVaultError) -> Bool {
        switch error {
        case .deviceChallengeFailed,
             .deviceAttestationFailed,
             .remoteTimedOut,
             .remoteNetworkUnavailable,
             .remoteSecureConnectionFailed:
            return true
        default:
            return false
        }
    }

    private static func shouldRetryAuthorizationPreparation(for error: Error) -> Bool {
        if let travelVaultError = error as? TravelVaultError {
            return shouldRetryDeviceRegistration(for: travelVaultError)
        }

        let nsError = error as NSError
        return nsError.domain == "com.apple.devicecheck.error"
    }

    private static func mapRemoteFailure(
        data: Data,
        statusCode: Int,
        defaultError: TravelVaultError
    ) -> TravelVaultError {
        if statusCode == 429 {
            return .remoteRateLimited
        }

        if let decoded = try? JSONDecoder().decode(DeviceRemoteFailureResponse.self, from: data) {
            if let code = decoded.code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
                switch code {
                case "invalid_device_challenge":
                    return .deviceChallengeFailed
                case "invalid_device_attestation", "missing_device_proof":
                    return .deviceAttestationFailed
                case "app_attest_not_configured":
                    if let message = decoded.message, !message.isEmpty {
                        return .remoteFailure(message: message)
                    }
                    return .remoteFailure(message: "App Attest is not configured on the travel-vault server.")
                default:
                    break
                }
            }

            if let message = decoded.message ?? decoded.error, !message.isEmpty {
                let normalized = message.lowercased()
                if statusCode == 403,
                   normalized.contains("1010") || normalized.contains("access denied") {
                    return .remoteAccessBlocked
                }
                return .remoteFailure(message: message)
            }
        }

        if statusCode == 403,
           let message = String(data: data, encoding: .utf8)?.lowercased(),
           message.contains("1010") || message.contains("access denied") {
            return .remoteAccessBlocked
        }

        return defaultError
    }

    // MARK: - Keychain Helpers / Keychain 辅助方法

    private static let keychainServiceName = OpenSourceProjectInfo.publicAppIdentifier + ".appattest"

    private static func saveKeychainString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        deleteKeychainItem(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadKeychainString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychainItem(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct TravelVaultAuthorizationProof {
    let keyID: String
    let challenge: String
    let assertion: Data
}

private struct DeviceChallengeResponse: Codable {
    let challenge: String
    let expiresAt: Date
}

private struct DeviceAttestRequest: Codable {
    let keyID: String
    let challenge: String
    let attestation: String

    enum CodingKeys: String, CodingKey {
        case keyID = "keyId"
        case challenge
        case attestation
    }
}

private struct DeviceAttestResponse: Codable {
    let registrationToken: String
}

private struct DeviceRegisterRequest: Codable {
    let registrationToken: String
}

private struct DeviceRemoteFailureResponse: Codable {
    let code: String?
    let error: String?
    let message: String?
}

private extension JSONDecoder {
    static var travelVaultDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
