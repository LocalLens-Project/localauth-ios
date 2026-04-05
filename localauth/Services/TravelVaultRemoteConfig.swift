import Foundation

enum TravelVaultRemoteConfig {
    // The public repo does not ship with a hosted backend. / 开源仓库默认不附带在线后端。
    // Fill these placeholders with your own deployment before using Travel Vault. / 使用 Travel Vault 前，请填入你自己的部署地址。
    static let customBaseURLString = OpenSourceProjectInfo.travelVaultBaseURLString
    static let customDeviceAttestBaseURLString = OpenSourceProjectInfo.travelVaultDeviceAttestBaseURLString

    static var baseURLString: String {
        customBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var deviceAttestBaseURLString: String {
        customDeviceAttestBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Keep these paths aligned with the Worker scaffold under / 让这些路径与 Worker 脚手架中的接口保持一致：
    // cloudflare-travel-vault-worker/src/index.ts. / cloudflare-travel-vault-worker/src/index.ts。
    static let createPath = "/api/travel-vaults"
    static let fetchPathPrefix = "/api/travel-vaults"
    static let deviceChallengePath = "/api/travel-vaults/device/challenge"
    static let deviceAttestPath = "/api/travel-vault/device/attest"
    static let deviceRegisterPath = "/api/travel-vaults/device/register"

    static var requestHeaders: [String: String] {
        var headers: [String: String] = [
            "Accept": "application/json, text/plain, */*",
            "Cache-Control": "no-store",
            "Pragma": "no-cache",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        ]

        let preferredLanguages = Locale.preferredLanguages.prefix(3)
        if !preferredLanguages.isEmpty {
            headers["Accept-Language"] = preferredLanguages.joined(separator: ", ")
        }

        for (key, value) in additionalHeaders {
            headers[key] = value
        }

        return headers
    }

    static let additionalHeaders: [String: String] = [:]

    static let retentionDays = 7
    static let schemaVersion = 2
    static let supportedSchemaVersions: Set<Int> = [1, 2]
}
