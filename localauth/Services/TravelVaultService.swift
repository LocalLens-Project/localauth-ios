import Foundation

final class TravelVaultService {
    static let shared = TravelVaultService()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func createTravelVault(with encryptedPackage: TravelVaultEncryptedPackage) async throws -> TravelVaultRemoteReceipt {
        let url = try makeBaseURL(path: TravelVaultRemoteConfig.createPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateTravelVaultRequest(
            schemaVersion: encryptedPackage.schemaVersion,
            wrappedSyncKey: encryptedPackage.wrappedSyncKey.base64EncodedString(),
            encryptedPayload: encryptedPackage.ciphertext.base64EncodedString(),
            retentionDays: TravelVaultRemoteConfig.retentionDays,
            platform: "ios"
        )
        request.httpBody = try encoder.encode(body)
        applyConfiguredHeaders(to: &request)

        let (data, response) = try await sendAuthorized(request)
        let httpResponse = try validate(response: response, data: data)
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw parseRemoteFailure(from: data, statusCode: httpResponse.statusCode)
        }

        do {
            let receipt = try decoder.decode(CreateTravelVaultResponse.self, from: data)
            return TravelVaultRemoteReceipt(
                pickupCode: TravelVaultCryptoService.formatPickupCode(receipt.pickupCode),
                expiresAt: receipt.expiresAt
            )
        } catch {
            throw TravelVaultError.invalidRemoteResponse
        }
    }

    func downloadTravelVault(pickupCode: String) async throws -> TravelVaultDownloadPayload {
        let normalizedCode = TravelVaultCryptoService.normalizePickupCode(pickupCode)
        guard !normalizedCode.isEmpty else {
            throw TravelVaultError.invalidPackage
        }

        let path = "\(TravelVaultRemoteConfig.fetchPathPrefix)/\(normalizedCode)"
        let url = try makeBaseURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        applyConfiguredHeaders(to: &request)

        let (data, response) = try await sendAuthorized(request)
        let httpResponse = try validate(response: response, data: data)
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw parseRemoteFailure(from: data, statusCode: httpResponse.statusCode)
        }

        do {
            let payload = try decoder.decode(FetchTravelVaultResponse.self, from: data)
            guard let wrappedSyncKey = Data(base64Encoded: payload.wrappedSyncKey),
                  let ciphertext = Data(base64Encoded: payload.encryptedPayload) else {
                throw TravelVaultError.invalidRemoteResponse
            }
            return TravelVaultDownloadPayload(
                encryptedPackage: TravelVaultEncryptedPackage(
                    schemaVersion: payload.schemaVersion,
                    wrappedSyncKey: wrappedSyncKey,
                    ciphertext: ciphertext
                ),
                expiresAt: payload.expiresAt
            )
        } catch let error as TravelVaultError {
            throw error
        } catch {
            throw TravelVaultError.invalidRemoteResponse
        }
    }

    private func makeBaseURL(path: String) throws -> URL {
        let trimmed = TravelVaultRemoteConfig.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let baseURL = URL(string: trimmed) else {
            throw TravelVaultError.remoteNotConfigured
        }
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw TravelVaultError.remoteNotConfigured
        }
        return url
    }

    private func applyConfiguredHeaders(to request: inout URLRequest) {
        for (key, value) in TravelVaultRemoteConfig.requestHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw mapTransportError(error)
        }
    }

    private func sendAuthorized(_ request: URLRequest, retryAfterReset: Bool = true) async throws -> (Data, URLResponse) {
        do {
            var authorizedRequest = request
            try await TravelVaultAppAttestService.applyAuthorizationHeaders(
                to: &authorizedRequest,
                session: session
            )
            let result = try await send(authorizedRequest)

            if retryAfterReset,
               let httpResponse = result.1 as? HTTPURLResponse,
               httpResponse.statusCode == 401,
               shouldRetryAfterAuthorizationReset(from: result.0) {
                TravelVaultAppAttestService.resetLocalRegistration()
                return try await sendAuthorized(request, retryAfterReset: false)
            }

            return result
        } catch {
            throw mapTransportError(error)
        }
    }

    private func validate(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TravelVaultError.invalidRemoteResponse
        }
        guard !data.isEmpty || httpResponse.statusCode == 204 else {
            throw TravelVaultError.invalidRemoteResponse
        }
        return httpResponse
    }

    private func parseRemoteFailure(from data: Data, statusCode: Int) -> Error {
        if let decoded = try? decoder.decode(RemoteFailureResponse.self, from: data),
           let message = decoded.error ?? decoded.message,
           !message.isEmpty {
            return mapRemoteFailure(message: message, code: decoded.code, statusCode: statusCode)
        }

        if let message = String(data: data, encoding: .utf8), !message.isEmpty {
            return mapRemoteFailure(message: message, code: nil, statusCode: statusCode)
        }

        if statusCode == 403 {
            return TravelVaultError.remoteAccessBlocked
        }

        return TravelVaultError.invalidRemoteResponse
    }

    private func mapRemoteFailure(message: String, code: String?, statusCode: Int) -> Error {
        if statusCode == 429 {
            return TravelVaultError.remoteRateLimited
        }
        if statusCode == 413 {
            return TravelVaultError.remotePayloadTooLarge
        }
        if statusCode == 401, isDeviceAuthorizationCode(code) {
            return TravelVaultError.deviceAttestationFailed
        }
        let normalized = message.lowercased()
        if statusCode == 403, normalized.contains("1010") {
            return TravelVaultError.remoteAccessBlocked
        }
        if statusCode == 403, normalized.contains("access denied") {
            return TravelVaultError.remoteAccessBlocked
        }
        return TravelVaultError.remoteFailure(message: message)
    }

    private func shouldRetryAfterAuthorizationReset(from data: Data) -> Bool {
        guard let decoded = try? decoder.decode(RemoteFailureResponse.self, from: data) else {
            return false
        }
        return isDeviceAuthorizationCode(decoded.code)
    }

    private func isDeviceAuthorizationCode(_ code: String?) -> Bool {
        switch code {
        case "device_not_registered", "invalid_device_assertion", "invalid_device_key":
            return true
        default:
            return false
        }
    }

    private func mapTransportError(_ error: Error) -> Error {
        guard let urlError = error as? URLError else {
            return error
        }

        switch urlError.code {
        case .timedOut:
            return TravelVaultError.remoteTimedOut
        case .networkConnectionLost,
             .notConnectedToInternet,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .dataNotAllowed,
             .internationalRoamingOff:
            return TravelVaultError.remoteNetworkUnavailable
        case .secureConnectionFailed,
             .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid,
             .serverCertificateUntrusted,
             .clientCertificateRejected,
             .clientCertificateRequired,
             .appTransportSecurityRequiresSecureConnection:
            return TravelVaultError.remoteSecureConnectionFailed
        default:
            return urlError
        }
    }
}

private struct CreateTravelVaultRequest: Codable {
    let schemaVersion: Int
    let wrappedSyncKey: String
    let encryptedPayload: String
    let retentionDays: Int
    let platform: String
}

private struct CreateTravelVaultResponse: Codable {
    let pickupCode: String
    let expiresAt: Date
}

private struct FetchTravelVaultResponse: Codable {
    let schemaVersion: Int
    let wrappedSyncKey: String
    let encryptedPayload: String
    let expiresAt: Date
}

private struct RemoteFailureResponse: Codable {
    let code: String?
    let error: String?
    let message: String?
}
