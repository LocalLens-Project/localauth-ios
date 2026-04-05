import Foundation
import SwiftData

struct DemoDataSeeder {
    static let demoSecretBase32 = "JBSWY3DPEHPK3PXP"
    
    struct DemoItem {
        let issuer: String
        let account: String
        let iconName: String
        let colorHex: String
        let tier: TokenTier
    }
    
    static let items: [DemoItem] = [
        DemoItem(issuer: "Example Mail", account: "demo@example.com", iconName: "envelope.fill", colorHex: "007AFF", tier: .normal),
        DemoItem(issuer: "Example Dev", account: "build@example.com", iconName: "terminal.fill", colorHex: "8E8E93", tier: .normal),
        DemoItem(issuer: "Example Secure", account: "vault@example.com", iconName: "shield.fill", colorHex: "FF3B30", tier: .confidential),
        DemoItem(issuer: "Example Office", account: "ops@example.com", iconName: "building.2.fill", colorHex: "00D4FF", tier: .normal),
        DemoItem(issuer: "Example Cloud", account: "infra@example.com", iconName: "globe", colorHex: "FF9500", tier: .normal)
    ]
    
    static func preloadDemoData(modelContext: ModelContext) throws {
        try modelContext.delete(model: TokenModel.self)

        let secretData = try Base32.decode(demoSecretBase32)
        let encryptedSeed = try DemoTokenCryptoService.encryptSecret(secretData)

        for (index, item) in items.enumerated() {
            let token = TokenModel(
                issuer: item.issuer,
                account: item.account,
                iconName: item.iconName,
                colorHex: item.colorHex,
                tier: item.tier,
                sortOrder: index,
                otpDigits: 6,
                otpPeriod: 30,
                otpAlgorithmRaw: TokenAlgorithm.sha1.rawValue,
                encryptedSeed: encryptedSeed,
                wrappedKey: nil,
                localSalt: nil,
                keychainTag: DemoTokenCryptoService.keychainTagPrefix + UUID().uuidString
            )
            modelContext.insert(token)
        }

        try modelContext.save()
    }
}
