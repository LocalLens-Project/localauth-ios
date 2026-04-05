import Foundation
import SwiftData
import CryptoKit

struct TokenTransferItem: Codable, Sendable {
    let issuer: String
    let account: String
    let secretBase32: String
    let iconName: String
    let colorHex: String
    let tier: TokenTier
    let digits: Int
    let period: Int
    let algorithm: TokenAlgorithm

    var label: String {
        if issuer.isEmpty {
            return account
        }
        return "\(issuer) (\(account))"
    }
}

struct TokenImportGuidance: Sendable {
    let totalCount: Int
    let confidentialCount: Int
    let hardwareFIDOCount: Int
    let normalCount: Int
    let portableCount: Int
    let sealedCount: Int
    let portableHardwareFIDOCount: Int
    let sealedConfidentialCount: Int
    let sealedHardwareFIDOCount: Int

    var hasHighSecurityTokens: Bool {
        confidentialCount > 0 || hardwareFIDOCount > 0
    }

    var requiresHardwarePINForImport: Bool {
        portableHardwareFIDOCount > 0
    }
}

enum TokenImportError: LocalizedError {
    case invalidPayload
    case hardwarePINRequired(tokenLabel: String)
    case creationFailed(tokenLabel: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return String(localized: "收到的同步数据无效，无法导入。")
        case .hardwarePINRequired(let tokenLabel):
            return String(format: String(localized: "导入“%@”前需要先输入硬件密钥PIN。"), tokenLabel)
        case .creationFailed(let tokenLabel, let reason):
            return String(format: String(localized: "导入“%@”失败：%@"), tokenLabel, reason)
        }
    }
}

@Observable
final class TokenStore {
    var tokens: [TokenModel] = []
    var decryptedCodes: [UUID: String] = [:]

    private var modelContext: ModelContext
    private let isDemoMode = ProcessInfo.processInfo.arguments.contains("-demo-mode")
    private let yubiKeyService = YubiKeyService.shared
    private let hardwareFIDOService = HardwareFIDOService()
    private var lastCodeCounters: [UUID: UInt64] = [:]
    private var refreshTimer: Timer?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchTokens()
        refreshCodes()
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Data Queries / 数据查询

    func fetchTokens() {
        let descriptor = FetchDescriptor<TokenModel>(sortBy: [SortDescriptor(\.sortOrder)])
        do {
            tokens = try modelContext.fetch(descriptor)
        } catch {
            assertionFailure("Failed to fetch tokens: \(error)")
        }
    }

    // MARK: - Timed Refresh / 定时刷新

    func refreshCodes() {
        let now = Date()

        for token in tokens {
            guard let secret = token.decryptedSecret else {
                lastCodeCounters.removeValue(forKey: token.id)
                continue
            }

            let counter = UInt64(floor(now.timeIntervalSince1970 / Double(token.resolvedPeriod)))
            guard lastCodeCounters[token.id] != counter || decryptedCodes[token.id] == nil else {
                continue
            }

            lastCodeCounters[token.id] = counter
            decryptedCodes[token.id] = generateCode(for: token, secret: secret, time: now)
        }
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshCodes()
        }
    }

    private func generateCode(for token: TokenModel, secret: Data, time: Date = Date()) -> String {
        TOTPGenerator.generate(
            secret: secret,
            time: time,
            period: token.resolvedPeriod,
            digits: token.resolvedDigits,
            algorithm: token.resolvedAlgorithm
        )
    }

    // MARK: - Unlock (Normal Tier: Secure Enclave + Face ID) / 解锁（普通级：Secure Enclave + Face ID）

    func unlockNormalToken(_ token: TokenModel) async throws {
        if try await unlockDemoTokenIfNeeded(token) {
            return
        }

        guard let wrappedKey = token.wrappedKey else { return }
        let encryptedSeed = token.encryptedSeed
        let tag = token.keychainTag

        let aesKeyData = try await Task.detached {
            let privateKey = try KeychainService.loadSEPrivateKey(tag: tag)
            return try KeychainService.unwrapKey(wrappedData: wrappedKey, withPrivateKey: privateKey)
        }.value

        let key = SymmetricKey(data: aesKeyData)
        let secret = try EncryptionService.decrypt(combined: encryptedSeed, key: key)
        await MainActor.run {
            token.decryptedSecret = secret
            decryptedCodes[token.id] = generateCode(for: token, secret: secret)
        }
    }

    // MARK: - Unlock (Confidential Tier: YubiKey) / 解锁（机密级：YubiKey）

    func unlockConfidentialToken(_ token: TokenModel) async throws {
        if try await unlockDemoTokenIfNeeded(token) {
            return
        }

        guard let salt = token.localSalt else { return }

        let challenge = YubiKeyService.challengeForToken(id: token.id)
        let hmacResponse = try await yubiKeyService.performChallengeResponse(challenge: challenge)
        let key = EncryptionService.deriveKey(hmacResponse: hmacResponse, salt: salt)
        let secret = try EncryptionService.decrypt(combined: token.encryptedSeed, key: key)
        await MainActor.run {
            token.decryptedSecret = secret
            decryptedCodes[token.id] = generateCode(for: token, secret: secret)
        }
    }

    func unlockHardwareFIDOToken(_ token: TokenModel, pin: String? = nil) async throws {
        if try await unlockDemoTokenIfNeeded(token) {
            return
        }

        guard let salt = token.localSalt, let credentialID = token.hardwareCredentialID else { return }
        let challenge = YubiKeyService.challengeForToken(id: token.id)
        let hmacResponse = try await hardwareFIDOService.performHMACSecret(
            challenge: challenge,
            credentialID: credentialID,
            pin: pin
        )
        let key = EncryptionService.deriveKey(hmacResponse: hmacResponse, salt: salt)
        let secret = try EncryptionService.decrypt(combined: token.encryptedSeed, key: key)
        await MainActor.run {
            token.decryptedSecret = secret
            decryptedCodes[token.id] = generateCode(for: token, secret: secret)
        }
    }

    func probeHardwareFIDOAuthenticator() async throws {
        try await hardwareFIDOService.probeAuthenticator()
    }

    // MARK: - Locking / 锁定

    func lockToken(_ token: TokenModel) {
        token.decryptedSecret = nil
        decryptedCodes.removeValue(forKey: token.id)
        lastCodeCounters.removeValue(forKey: token.id)
    }

    func lockAll() {
        for token in tokens {
            token.decryptedSecret = nil
        }
        decryptedCodes.removeAll()
        lastCodeCounters.removeAll()
    }

    // MARK: - Add Tokens / 添加令牌

    func addToken(
        issuer: String,
        account: String,
        secretBase32: String,
        iconName: String,
        colorHex: String,
        tier: TokenTier,
        digits: Int = 6,
        period: Int = 30,
        algorithm: TokenAlgorithm = .sha1,
        hardwarePIN: String? = nil
    ) async throws {
        let secretData = try Base32.decode(secretBase32)
        let keychainTag = "localauth-\(UUID().uuidString)"
        let tokenId = UUID()
        let normalizedDigits = min(max(digits, 1), 10)
        let normalizedPeriod = max(period, 1)

        let encryptedSeed: Data
        var wrappedKey: Data? = nil
        var localSalt: Data? = nil
        var hardwareCredentialID: Data? = nil

        switch tier {
        case .normal:
            let result = try await Task.detached { () -> (wrapped: Data, encrypted: Data) in
                let privateKey = try KeychainService.generateSEKeyPair(tag: keychainTag)
                guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
                    throw KeychainError.publicKeyNotFound
                }
                let aesKeyData = try EncryptionService.generateRandomBytes(32)
                let wrapped = try KeychainService.wrapKey(data: aesKeyData, withPublicKey: publicKey)
                let key = SymmetricKey(data: aesKeyData)
                let encrypted = try EncryptionService.encrypt(data: secretData, key: key)
                return (wrapped, encrypted)
            }.value
            wrappedKey = result.wrapped
            encryptedSeed = result.encrypted

        case .confidential:
            let salt = try EncryptionService.generateRandomBytes(32)
            localSalt = salt
            let challenge = YubiKeyService.challengeForToken(id: tokenId)
            let hmacResponse = try await yubiKeyService.performChallengeResponse(challenge: challenge)
            let key = EncryptionService.deriveKey(hmacResponse: hmacResponse, salt: salt)
            encryptedSeed = try EncryptionService.encrypt(data: secretData, key: key)

        case .hardwareFIDO:
            let pin = hardwarePIN?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let pin, !pin.isEmpty else {
                throw HardwareFIDOError.pinRequired
            }

            let salt = try EncryptionService.generateRandomBytes(32)
            localSalt = salt
            let challenge = YubiKeyService.challengeForToken(id: tokenId)
            let registration = try await hardwareFIDOService.registerHMACSecretCredential(
                challenge: challenge,
                pin: pin
            )
            hardwareCredentialID = registration.credentialID
            let key = EncryptionService.deriveKey(hmacResponse: registration.hmacOutput, salt: salt)
            encryptedSeed = try EncryptionService.encrypt(data: secretData, key: key)
        }

        let token = TokenModel(
            id: tokenId,
            issuer: issuer,
            account: account,
            iconName: iconName,
            colorHex: colorHex,
            tier: tier,
            sortOrder: tokens.count,
            otpDigits: normalizedDigits,
            otpPeriod: normalizedPeriod,
            otpAlgorithmRaw: algorithm.rawValue,
            encryptedSeed: encryptedSeed,
            wrappedKey: wrappedKey,
            localSalt: localSalt,
            hardwareCredentialID: hardwareCredentialID,
            keychainTag: keychainTag
        )

        try await MainActor.run {
            modelContext.insert(token)
            try modelContext.save()
            fetchTokens()
        }
    }

    // MARK: - Delete Tokens / 删除令牌

    func deleteToken(_ token: TokenModel) {
        KeychainService.deleteKey(tag: token.keychainTag)
        decryptedCodes.removeValue(forKey: token.id)
        lastCodeCounters.removeValue(forKey: token.id)
        modelContext.delete(token)
        try? modelContext.save()
        fetchTokens()
    }

    func updateTokenAppearance(_ token: TokenModel, iconName: String, colorHex: String) throws {
        token.iconName = iconName
        token.colorHex = colorHex
        try modelContext.save()
        fetchTokens()
    }

    func currentTokenGuidance() -> TokenImportGuidance {
        TokenImportGuidanceBuilder.make(from: tokens)
    }

    func prepareTravelVaultPackage(sourceDeviceName: String) async throws -> TravelVaultPreparation {
        guard !tokens.isEmpty else {
            throw TravelVaultError.noTokens
        }

        var exportItems: [TravelVaultTokenItem] = []
        exportItems.reserveCapacity(tokens.count)
        var tokensUnlockedForExport: [TokenModel] = []

        defer {
            for token in tokensUnlockedForExport {
                lockToken(token)
            }
        }

        for token in tokens {
            if let demoSecret = demoSecretIfAvailable(for: token) {
                exportItems.append(
                    TravelVaultTokenItem(
                        issuer: token.issuer,
                        account: token.account,
                        secretBase32: Base32.encode(demoSecret),
                        iconName: token.iconName,
                        colorHex: token.colorHex,
                        tier: token.tier,
                        digits: token.resolvedDigits,
                        period: token.resolvedPeriod,
                        algorithm: token.resolvedAlgorithm,
                        storageMode: .portableSecret,
                        tokenID: nil,
                        encryptedSeed: nil,
                        wrappedKey: nil,
                        localSalt: nil,
                        hardwareCredentialID: nil
                    )
                )
                continue
            }

            switch token.tier {
            case .normal:
                let wasLocked = token.decryptedSecret == nil
                if wasLocked {
                    try await unlockNormalToken(token)
                    tokensUnlockedForExport.append(token)
                }

                guard let secret = token.decryptedSecret else {
                    throw TravelVaultError.secretUnavailable(tokenLabel: token.displayLabel)
                }

                exportItems.append(
                    TravelVaultTokenItem(
                        issuer: token.issuer,
                        account: token.account,
                        secretBase32: Base32.encode(secret),
                        iconName: token.iconName,
                        colorHex: token.colorHex,
                        tier: token.tier,
                        digits: token.resolvedDigits,
                        period: token.resolvedPeriod,
                        algorithm: token.resolvedAlgorithm,
                        storageMode: .portableSecret,
                        tokenID: nil,
                        encryptedSeed: nil,
                        wrappedKey: nil,
                        localSalt: nil,
                        hardwareCredentialID: nil
                    )
                )

            case .confidential:
                guard let localSalt = token.localSalt else {
                    throw TravelVaultError.sealedStateUnavailable(tokenLabel: token.displayLabel)
                }

                exportItems.append(
                    TravelVaultTokenItem(
                        issuer: token.issuer,
                        account: token.account,
                        secretBase32: nil,
                        iconName: token.iconName,
                        colorHex: token.colorHex,
                        tier: token.tier,
                        digits: token.resolvedDigits,
                        period: token.resolvedPeriod,
                        algorithm: token.resolvedAlgorithm,
                        storageMode: .sealedTokenShell,
                        tokenID: token.id,
                        encryptedSeed: token.encryptedSeed,
                        wrappedKey: token.wrappedKey,
                        localSalt: localSalt,
                        hardwareCredentialID: nil
                    )
                )

            case .hardwareFIDO:
                guard let localSalt = token.localSalt,
                      let hardwareCredentialID = token.hardwareCredentialID else {
                    throw TravelVaultError.sealedStateUnavailable(tokenLabel: token.displayLabel)
                }

                exportItems.append(
                    TravelVaultTokenItem(
                        issuer: token.issuer,
                        account: token.account,
                        secretBase32: nil,
                        iconName: token.iconName,
                        colorHex: token.colorHex,
                        tier: token.tier,
                        digits: token.resolvedDigits,
                        period: token.resolvedPeriod,
                        algorithm: token.resolvedAlgorithm,
                        storageMode: .sealedTokenShell,
                        tokenID: token.id,
                        encryptedSeed: token.encryptedSeed,
                        wrappedKey: token.wrappedKey,
                        localSalt: localSalt,
                        hardwareCredentialID: hardwareCredentialID
                    )
                )
            }
        }

        let package = TravelVaultPackage(
            schemaVersion: TravelVaultRemoteConfig.schemaVersion,
            createdAt: Date(),
            sourceDeviceName: sourceDeviceName,
            tokens: exportItems
        )
        let encodedPackage = try JSONEncoder().encode(package)

        return TravelVaultPreparation(
            package: package,
            encodedPackage: encodedPackage,
            guidance: guidance(for: exportItems)
        )
    }

    @discardableResult
    private func importPortableToken(_ item: TokenTransferItem, hardwarePIN: String? = nil) async throws -> Int {
        let normalizedHardwarePIN = hardwarePIN?.trimmingCharacters(in: .whitespacesAndNewlines)
        if item.tier == .hardwareFIDO, normalizedHardwarePIN?.isEmpty != false {
            throw TokenImportError.hardwarePINRequired(tokenLabel: item.label)
        }

        do {
            try await addToken(
                issuer: item.issuer,
                account: item.account,
                secretBase32: item.secretBase32,
                iconName: item.iconName,
                colorHex: item.colorHex,
                tier: item.tier,
                digits: item.digits,
                period: item.period,
                algorithm: item.algorithm,
                hardwarePIN: normalizedHardwarePIN
            )

            if item.tier == .hardwareFIDO || item.tier == .confidential {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            return 1
        } catch let error as TokenImportError {
            throw error
        } catch {
            throw TokenImportError.creationFailed(tokenLabel: item.label, reason: error.localizedDescription)
        }
    }

    @discardableResult
    private func importSealedTravelVaultToken(_ item: TravelVaultTokenItem, reservedTokenIDs: inout Set<UUID>) async throws -> Int {
        guard item.resolvedStorageMode == .sealedTokenShell else {
            throw TokenImportError.creationFailed(
                tokenLabel: item.label,
                reason: String(localized: "当前旅行寄存条目不是密文壳恢复格式。")
            )
        }

        guard item.tier != .normal else {
            throw TokenImportError.creationFailed(
                tokenLabel: item.label,
                reason: String(localized: "普通级旅行寄存必须使用可恢复副本，不能按原密文壳恢复。")
            )
        }

        guard let tokenID = item.tokenID,
              let encryptedSeed = item.encryptedSeed else {
            throw TokenImportError.creationFailed(
                tokenLabel: item.label,
                reason: String(localized: "旅行寄存条目缺少必要的密文元数据。")
            )
        }

        guard !reservedTokenIDs.contains(tokenID) else {
            throw TokenImportError.creationFailed(
                tokenLabel: item.label,
                reason: String(localized: "当前设备已存在相同标识的密封令牌，请先移除旧副本再恢复。")
            )
        }

        switch item.tier {
        case .confidential:
            guard item.localSalt != nil else {
                throw TokenImportError.creationFailed(
                    tokenLabel: item.label,
                    reason: String(localized: "机密级旅行寄存条目缺少本地盐，无法恢复。")
                )
            }
        case .hardwareFIDO:
            guard item.localSalt != nil, item.hardwareCredentialID != nil else {
                throw TokenImportError.creationFailed(
                    tokenLabel: item.label,
                    reason: String(localized: "通用硬件密钥旅行寄存条目缺少 hmac-secret 元数据，无法恢复。")
                )
            }
        case .normal:
            break
        }

        let token = TokenModel(
            id: tokenID,
            issuer: item.issuer,
            account: item.account,
            iconName: item.iconName,
            colorHex: item.colorHex,
            tier: item.tier,
            sortOrder: tokens.count,
            otpDigits: item.digits,
            otpPeriod: item.period,
            otpAlgorithmRaw: item.algorithm.rawValue,
            encryptedSeed: encryptedSeed,
            wrappedKey: item.wrappedKey,
            localSalt: item.localSalt,
            hardwareCredentialID: item.hardwareCredentialID,
            keychainTag: "localauth-\(UUID().uuidString)"
        )

        try await MainActor.run {
            modelContext.insert(token)
            try modelContext.save()
            fetchTokens()
        }
        reservedTokenIDs.insert(tokenID)
        return 1
    }

    @discardableResult
    func wipeAllTokens() throws -> Int {
        let currentTokens = tokens
        guard !currentTokens.isEmpty else { return 0 }

        for token in currentTokens {
            KeychainService.deleteKey(tag: token.keychainTag)
            modelContext.delete(token)
        }

        try modelContext.save()
        lockAll()
        fetchTokens()
        return currentTokens.count
    }

    // MARK: - P2P Sync Export / P2P 同步导出

    func exportTokens() throws -> Data {
        let exportList = tokens.compactMap { token -> TokenTransferItem? in
            guard let secret = token.decryptedSecret else { return nil }
            return TokenTransferItem(
                issuer: token.issuer,
                account: token.account,
                secretBase32: Base32.encode(secret),
                iconName: token.iconName,
                colorHex: token.colorHex,
                tier: token.tier,
                digits: token.resolvedDigits,
                period: token.resolvedPeriod,
                algorithm: token.resolvedAlgorithm
            )
        }
        return try JSONEncoder().encode(exportList)
    }

    func parseImportPayload(from data: Data) throws -> [TokenTransferItem] {
        do {
            return try JSONDecoder().decode([TokenTransferItem].self, from: data)
        } catch {
            throw TokenImportError.invalidPayload
        }
    }

    func guidance(for items: [TokenTransferItem]) -> TokenImportGuidance {
        TokenImportGuidanceBuilder.make(from: items)
    }

    func guidance(for items: [TravelVaultTokenItem]) -> TokenImportGuidance {
        TokenImportGuidanceBuilder.make(from: items)
    }

    // MARK: - P2P Sync Import / P2P 同步导入

    @discardableResult
    func importTokens(_ items: [TokenTransferItem], hardwarePIN: String? = nil) async throws -> Int {
        for item in items {
            _ = try await importPortableToken(item, hardwarePIN: hardwarePIN)
        }

        return items.count
    }

    @discardableResult
    func importTravelVaultTokens(_ items: [TravelVaultTokenItem], hardwarePIN: String? = nil) async throws -> Int {
        var reservedTokenIDs = Set(tokens.map(\.id))

        for item in items {
            switch item.resolvedStorageMode {
            case .portableSecret:
                guard let secretBase32 = item.secretBase32 else {
                    throw TokenImportError.creationFailed(
                        tokenLabel: item.label,
                        reason: String(localized: "旅行寄存条目缺少可恢复明文副本。")
                    )
                }

                let portableItem = TokenTransferItem(
                    issuer: item.issuer,
                    account: item.account,
                    secretBase32: secretBase32,
                    iconName: item.iconName,
                    colorHex: item.colorHex,
                    tier: item.tier,
                    digits: item.digits,
                    period: item.period,
                    algorithm: item.algorithm
                )
                _ = try await importPortableToken(portableItem, hardwarePIN: hardwarePIN)

            case .sealedTokenShell:
                _ = try await importSealedTravelVaultToken(item, reservedTokenIDs: &reservedTokenIDs)
            }
        }

        return items.count
    }

    @discardableResult
    func importTokens(from data: Data, hardwarePIN: String? = nil) async throws -> Int {
        let items = try parseImportPayload(from: data)
        return try await importTokens(items, hardwarePIN: hardwarePIN)
    }
}

private extension TokenModel {
    var displayLabel: String {
        if issuer.isEmpty {
            return account
        }
        return "\(issuer) (\(account))"
    }
}

private extension TokenStore {
    func demoSecretIfAvailable(for token: TokenModel) -> Data? {
        guard isDemoMode, DemoTokenCryptoService.isDemoToken(token) else {
            return nil
        }
        return try? DemoTokenCryptoService.decryptSecret(token.encryptedSeed)
    }

    func unlockDemoTokenIfNeeded(_ token: TokenModel) async throws -> Bool {
        guard let secret = demoSecretIfAvailable(for: token) else {
            return false
        }

        await MainActor.run {
            token.decryptedSecret = secret
            decryptedCodes[token.id] = generateCode(for: token, secret: secret)
        }
        return true
    }
}
