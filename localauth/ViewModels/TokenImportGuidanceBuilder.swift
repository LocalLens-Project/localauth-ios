import Foundation

enum TokenImportGuidanceBuilder {
    static func make(from tokens: [TokenModel]) -> TokenImportGuidance {
        let normalCount = tokens.filter { $0.tier == .normal }.count
        let confidentialCount = tokens.filter { $0.tier == .confidential }.count
        let hardwareFIDOCount = tokens.filter { $0.tier == .hardwareFIDO }.count

        return TokenImportGuidance(
            totalCount: tokens.count,
            confidentialCount: confidentialCount,
            hardwareFIDOCount: hardwareFIDOCount,
            normalCount: normalCount,
            portableCount: normalCount,
            sealedCount: confidentialCount + hardwareFIDOCount,
            portableHardwareFIDOCount: 0,
            sealedConfidentialCount: confidentialCount,
            sealedHardwareFIDOCount: hardwareFIDOCount
        )
    }

    static func make(from items: [TokenTransferItem]) -> TokenImportGuidance {
        let normalCount = items.filter { $0.tier == .normal }.count
        let confidentialCount = items.filter { $0.tier == .confidential }.count
        let hardwareFIDOCount = items.filter { $0.tier == .hardwareFIDO }.count

        return TokenImportGuidance(
            totalCount: items.count,
            confidentialCount: confidentialCount,
            hardwareFIDOCount: hardwareFIDOCount,
            normalCount: normalCount,
            portableCount: items.count,
            sealedCount: 0,
            portableHardwareFIDOCount: hardwareFIDOCount,
            sealedConfidentialCount: 0,
            sealedHardwareFIDOCount: 0
        )
    }

    static func make(from items: [TravelVaultTokenItem]) -> TokenImportGuidance {
        let normalCount = items.filter { $0.tier == .normal }.count
        let confidentialCount = items.filter { $0.tier == .confidential }.count
        let hardwareFIDOCount = items.filter { $0.tier == .hardwareFIDO }.count
        let portableItems = items.filter { $0.resolvedStorageMode == .portableSecret }
        let sealedItems = items.filter { $0.resolvedStorageMode == .sealedTokenShell }

        return TokenImportGuidance(
            totalCount: items.count,
            confidentialCount: confidentialCount,
            hardwareFIDOCount: hardwareFIDOCount,
            normalCount: normalCount,
            portableCount: portableItems.count,
            sealedCount: sealedItems.count,
            portableHardwareFIDOCount: portableItems.filter { $0.tier == .hardwareFIDO }.count,
            sealedConfidentialCount: sealedItems.filter { $0.tier == .confidential }.count,
            sealedHardwareFIDOCount: sealedItems.filter { $0.tier == .hardwareFIDO }.count
        )
    }
}
