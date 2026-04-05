import SwiftUI
import UIKit

private enum TravelVaultMode: String, CaseIterable, Identifiable {
    case backup
    case restore

    var id: Self { self }

    var title: String {
        switch self {
        case .backup:
            return String(localized: "创建旅行寄存")
        case .restore:
            return String(localized: "恢复旅行寄存")
        }
    }
}

private enum TravelVaultPINContext {
    case restore
}

struct TravelVaultView: View {
    var tokenStore: TokenStore

    @Environment(\.dismiss) private var dismiss
    @AppStorage("rememberHardwarePinEnabled") private var rememberHardwarePinEnabled = false

    @State private var mode: TravelVaultMode = .backup
    @State private var uploadReceipt: TravelVaultUploadReceipt?
    @State private var hasConfirmedRecoveryMaterialSaved = false

    @State private var pickupCodeInput = ""
    @State private var recoveryKeyInput = ""
    @State private var pendingRestorePackage: TravelVaultPackage?
    @State private var pendingRestoreGuidance: TokenImportGuidance?
    @State private var pendingRestoreSourceName: String?
    @State private var downloadedExpiresAt: Date?

    @State private var isBusy = false
    @State private var progressMessage: String?
    @State private var infoMessage: String?
    @State private var errorMessage: String?
    @State private var showWipeConfirmation = false
    @State private var showHardwarePINPrompt = false
    @State private var pendingHardwarePINSubmission: String?
    @State private var hardwarePINContext: TravelVaultPINContext?

    private let themeCyan = Color(red: 0.2, green: 0.85, blue: 0.98)

    private var currentGuidance: TokenImportGuidance {
        tokenStore.currentTokenGuidance()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    Picker("", selection: $mode) {
                        ForEach(TravelVaultMode.allCases) { currentMode in
                            Text(currentMode.title).tag(currentMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .background(Color(uiColor: .systemGroupedBackground))

                    Form {
                        if mode == .backup {
                            backupSections
                        } else {
                            restoreSections
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color(uiColor: .systemGroupedBackground))
                }
                .allowsHitTesting(!isBusy)

                if let progressMessage, isBusy {
                    busyOverlay(progressMessage)
                        .transition(.opacity)
                }
            }
            .navigationTitle(String(localized: "旅行寄存"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "关闭")) {
                        dismiss()
                    }
                    .foregroundColor(themeCyan)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showHardwarePINPrompt, onDismiss: handlePendingHardwarePINSubmission) {
                HardwarePINPromptView(
                    title: String(localized: "输入硬件密钥PIN"),
                    subtitle: hardwarePINSubtitle,
                    requiresConfirmation: false,
                    confirmTitle: String(localized: "继续")
                ) { pin in
                    pendingHardwarePINSubmission = pin
                } onCancel: {
                    pendingHardwarePINSubmission = nil
                }
            }
            .alert(String(localized: "旅行寄存"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "确定"), role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert(String(localized: "已完成"), isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )) {
                Button(String(localized: "确定"), role: .cancel) {
                    infoMessage = nil
                }
            } message: {
                Text(infoMessage ?? "")
            }
            .confirmationDialog(
                String(localized: "确认抹掉本机令牌"),
                isPresented: $showWipeConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "我已保存恢复材料，立即抹掉"), role: .destructive) {
                    wipeLocalTokensAfterBackup()
                }
                Button(String(localized: "取消"), role: .cancel) {}
            } message: {
                Text(String(localized: "该操作会删除本机全部令牌与保存的硬件密钥PIN，仅保留已上传的旅行寄存密文。"))
            }
        }
    }

    @ViewBuilder
    private var backupSections: some View {
        if let uploadReceipt {
            receiptSections(uploadReceipt)
        } else {
            backupPreparationSections
        }
    }

    @ViewBuilder
    private var restoreSections: some View {
        if let guidance = pendingRestoreGuidance {
            restoreDownloadedSections(guidance)
        } else {
            restoreFormSections
        }
    }

    @ViewBuilder
    private var backupPreparationSections: some View {
        Section {
            introBlock(
                title: String(localized: "临时加密寄存"),
                subtitle: String(localized: "仅在你主动启用时，普通级会重打包成可恢复副本，更高安全级会保留当前密文壳。上传完成后，你可以彻底抹掉本机令牌。")
            )
        }

        Section {
            summaryValueRow(
                title: String(localized: "当前令牌总数"),
                value: String(currentGuidance.totalCount)
            )
        }

        if currentGuidance.confidentialCount > 0 || currentGuidance.hardwareFIDOCount > 0 || currentGuidance.totalCount > 0 {
            Section(header: Text(String(localized: "包含的令牌类型"))) {
                if currentGuidance.confidentialCount > 0 {
                    featureRow(
                        icon: "sensor.tag.radiowaves.forward",
                        title: String(localized: "包含 YubiKey 机密级令牌"),
                        description: String(localized: "这些令牌会直接上传当前密文壳。创建旅行寄存时不需要逐个做 challenge-response，但恢复后仍需原来的 YubiKey 才能解锁。")
                    )
                }

                if currentGuidance.hardwareFIDOCount > 0 {
                    featureRow(
                        icon: "key.horizontal.fill",
                        title: String(localized: "包含通用硬件密钥令牌"),
                        description: String(localized: "这些令牌会直接上传当前密文壳。创建旅行寄存时不需要读取 hmac-secret 或输入 PIN，但恢复后仍需原来的硬件密钥与凭据才能解锁。")
                    )
                }

                featureRow(
                    icon: "faceid",
                    title: String(localized: "普通级也会重打包"),
                    description: String(localized: "普通级令牌会先在本机解密，再用独立的旅行 sync key 重加密。恢复后会为当前设备重新创建 Secure Enclave 包装。")
                )
            }
        }

        Section(footer: footnoteStack([
            String(localized: "上传完成后，系统会显示短取件码和长恢复密钥。只有同时保存两者，之后才能恢复。"),
            String(localized: "同一安装实例再次创建旅行寄存时，会覆盖此前未过期的旅行寄存。"),
            String(localized: "只有在你点击创建或下载旅行寄存时，应用才会连接 Apple 设备证明服务与旅行寄存服务器。平时不会为此功能自动联网。")
        ])) {
            primaryActionRow(
                title: String(localized: "创建旅行寄存"),
                enabled: currentGuidance.totalCount > 0 && !isBusy,
                action: beginBackupFlow
            )
        }
    }

    @ViewBuilder
    private func receiptSections(_ receipt: TravelVaultUploadReceipt) -> some View {
        Section {
            introBlock(
                title: String(localized: "旅行寄存已创建"),
                subtitle: String(localized: "请先保存下面两样恢复材料。仅凭取件码无法解密云端密文。")
            )
        }

        Section {
            receiptValueRow(
                title: String(localized: "取件码"),
                value: receipt.pickupCode,
                copyValue: receipt.pickupCode
            )

            receiptValueRow(
                title: String(localized: "恢复密钥"),
                value: receipt.recoveryKeyDisplay,
                copyValue: receipt.recoveryKeyDisplay
            )

            summaryValueRow(
                title: String(localized: "过期时间"),
                value: TravelVaultFormatting.displayDate(receipt.expiresAt)
            )
        }

        Section {
            Toggle(isOn: $hasConfirmedRecoveryMaterialSaved) {
                Text(String(localized: "我已离线保存取件码与恢复密钥"))
                    .foregroundStyle(.primary)
            }
            .tint(themeCyan)

            ShareLink(item: receipt.shareText) {
                Label(String(localized: "分享恢复材料"), systemImage: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeCyan)
            }
        }

        Section(footer: Text(String(localized: "抹掉后，本机现有令牌、Secure Enclave 包装与保存的硬件密钥PIN都会被删除。"))) {
            destructiveActionRow(
                title: String(localized: "立即抹掉本机全部令牌"),
                enabled: hasConfirmedRecoveryMaterialSaved && !isBusy,
                action: { showWipeConfirmation = true }
            )
        }
    }

    @ViewBuilder
    private var restoreFormSections: some View {
        Section {
            introBlock(
                title: String(localized: "下载并恢复"),
                subtitle: String(localized: "输入取件码下载加密备份，再使用恢复密钥在本机解密。普通级会在当前设备重新绑定，其他高安全级会按原密文壳恢复。")
            )
        }

        Section(header: Text(String(localized: "凭据信息"))) {
            inlineField(
                title: String(localized: "取件码"),
                text: $pickupCodeInput,
                placeholder: "1234 5678 9012",
                keyboard: .numberPad,
                capitalization: .never
            )

            inlineField(
                title: String(localized: "恢复密钥"),
                text: $recoveryKeyInput,
                placeholder: "ABCD-EFGH-IJKL-MNOP",
                keyboard: .asciiCapable,
                capitalization: .characters
            )
        }

        Section(footer: footnoteStack([
            String(localized: "只有在你点击创建或下载旅行寄存时，应用才会连接 Apple 设备证明服务与旅行寄存服务器。平时不会为此功能自动联网。")
        ])) {
            primaryActionRow(
                title: String(localized: "下载旅行寄存"),
                enabled: canDownload && !isBusy,
                action: downloadTravelVault
            )
        }
    }

    @ViewBuilder
    private func restoreDownloadedSections(_ guidance: TokenImportGuidance) -> some View {
        if pendingRestoreSourceName != nil || downloadedExpiresAt != nil {
            Section {
                if let sourceName = pendingRestoreSourceName {
                    summaryValueRow(
                        title: String(localized: "备份来源设备"),
                        value: sourceName
                    )
                }

                if let expiresAt = downloadedExpiresAt {
                    summaryValueRow(
                        title: String(localized: "当前备份过期时间"),
                        value: TravelVaultFormatting.displayDate(expiresAt)
                    )
                }
            }
        }

        restorePreviewSections(guidance)
    }

    @ViewBuilder
    private func restorePreviewSections(_ guidance: TokenImportGuidance) -> some View {
        Section {
            introBlock(
                title: String(localized: "恢复预览"),
                subtitle: String(localized: "确认恢复前，应用会按令牌等级分别重建本地保护或恢复原密文壳。")
            )
        }

        Section {
            summaryValueRow(
                title: String(localized: "待恢复令牌"),
                value: String(guidance.totalCount)
            )
        }

        if guidance.confidentialCount > 0 || guidance.hardwareFIDOCount > 0 {
            Section(header: Text(String(localized: "包含的令牌类型"))) {
                if guidance.confidentialCount > 0 {
                    featureRow(
                        icon: "sensor.tag.radiowaves.forward",
                        title: String(localized: "包含 YubiKey 机密级令牌"),
                        description: String(localized: guidance.sealedConfidentialCount == guidance.confidentialCount
                            ? "这些令牌会按原密文壳恢复，恢复过程中不需要重新做 challenge-response。之后解锁时，仍需要原来的 YubiKey。"
                            : "恢复内容中仍包含需要重新建立的旧版 YubiKey 副本，因此导入时需要再次完成 challenge-response。")
                    )
                }

                if guidance.hardwareFIDOCount > 0 {
                    featureRow(
                        icon: "key.horizontal.fill",
                        title: String(localized: "包含通用硬件密钥令牌"),
                        description: String(localized: guidance.requiresHardwarePINForImport
                            ? "恢复内容中仍包含需要重新创建的旧版通用硬件密钥副本，因此导入时需要硬件密钥PIN。"
                            : "这些令牌会按原密文壳恢复，恢复过程中不需要重新创建 hmac-secret 凭据。之后解锁时，仍需要原来的硬件密钥与 PIN。")
                    )
                }
            }
        }

        Section {
            primaryActionRow(
                title: String(localized: "开始恢复到本机"),
                enabled: !isBusy,
                action: beginRestoreImportFlow
            )
        }
    }

    private func introBlock(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func summaryValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(themeCyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func inlineField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType,
        capitalization: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(true)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.vertical, 4)
    }

    private func receiptValueRow(title: String, value: String, copyValue: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(localized: "复制")) {
                    UIPasteboard.general.string = copyValue
                    infoMessage = String(localized: "已复制到剪贴板。")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeCyan)
            }

            Text(value)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 4)
    }

    private func primaryActionRow(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(enabled ? .black : .secondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(themeCyan)
        .controlSize(.large)
        .disabled(!enabled)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private func destructiveActionRow(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(enabled ? .red : .gray)
        .controlSize(.large)
        .disabled(!enabled)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private func footnoteStack(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
        .padding(.top, 4)
    }

    private func busyOverlay(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(themeCyan)

                Text(message)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.24), radius: 24, y: 10)
        }
    }

    private func beginBackupFlow() {
        guard !isBusy else { return }
        createTravelVault()
    }

    private func createTravelVault() {
        guard !isBusy else { return }
        isBusy = true
        progressMessage = String(localized: "正在整理旅行寄存令牌…")

        Task { @MainActor in
            do {
                let prepared = try await tokenStore.prepareTravelVaultPackage(
                    sourceDeviceName: UIDevice.current.name
                )
                let recoverySecret = try TravelVaultCryptoService.generateRecoverySecret()
                let encryptedPackage = try TravelVaultCryptoService.encryptPackage(
                    prepared.encodedPackage,
                    recoverySecret: recoverySecret
                )

                progressMessage = String(localized: "正在上传旅行寄存密文…")
                let remoteReceipt = try await TravelVaultService.shared.createTravelVault(with: encryptedPackage)

                uploadReceipt = TravelVaultUploadReceipt(
                    pickupCode: remoteReceipt.pickupCode,
                    expiresAt: remoteReceipt.expiresAt,
                    recoveryKeyDisplay: TravelVaultCryptoService.formatRecoveryKey(recoverySecret)
                )
                hasConfirmedRecoveryMaterialSaved = false
            } catch {
                errorMessage = error.localizedDescription
            }

            isBusy = false
            progressMessage = nil
        }
    }

    private func wipeLocalTokensAfterBackup() {
        guard !isBusy else { return }
        isBusy = true
        progressMessage = String(localized: "正在抹掉本机令牌…")

        Task { @MainActor in
            do {
                let removedCount = try tokenStore.wipeAllTokens()
                PINVaultService.delete()
                rememberHardwarePinEnabled = false
                mode = .restore
                uploadReceipt = nil
                hasConfirmedRecoveryMaterialSaved = false
                pendingRestorePackage = nil
                pendingRestoreGuidance = nil
                pendingRestoreSourceName = nil
                downloadedExpiresAt = nil
                infoMessage = String(format: String(localized: "已完成旅行寄存，本机共清空 %lld 个令牌。"), removedCount)
            } catch {
                errorMessage = error.localizedDescription
            }

            isBusy = false
            progressMessage = nil
        }
    }

    private func downloadTravelVault() {
        guard canDownload, !isBusy else { return }
        isBusy = true
        progressMessage = String(localized: "正在下载旅行寄存密文…")

        Task { @MainActor in
            do {
                let recoverySecret = try TravelVaultCryptoService.parseRecoveryKey(recoveryKeyInput)
                let downloadPayload = try await TravelVaultService.shared.downloadTravelVault(pickupCode: pickupCodeInput)

                progressMessage = String(localized: "正在本机解密旅行寄存…")
                let decrypted = try TravelVaultCryptoService.decryptPackage(
                    downloadPayload.encryptedPackage,
                    recoverySecret: recoverySecret
                )

                let decodedPackage = try JSONDecoder().decode(TravelVaultPackage.self, from: decrypted)
                guard TravelVaultRemoteConfig.supportedSchemaVersions.contains(decodedPackage.schemaVersion) else {
                    throw TravelVaultError.unsupportedSchemaVersion
                }
                guard !decodedPackage.tokens.isEmpty else {
                    throw TravelVaultError.invalidPackage
                }

                withAnimation(.easeInOut(duration: 0.25)) {
                    pendingRestorePackage = decodedPackage
                    pendingRestoreGuidance = tokenStore.guidance(for: decodedPackage.tokens)
                    pendingRestoreSourceName = decodedPackage.sourceDeviceName
                    downloadedExpiresAt = downloadPayload.expiresAt
                }
            } catch {
                errorMessage = error.localizedDescription
            }

            isBusy = false
            progressMessage = nil
        }
    }

    private func beginRestoreImportFlow() {
        guard !isBusy else { return }
        guard let guidance = pendingRestoreGuidance else { return }

        if guidance.requiresHardwarePINForImport,
           (!rememberHardwarePinEnabled || (PINVaultService.load()?.isEmpty ?? true)) {
            hardwarePINContext = .restore
            showHardwarePINPrompt = true
            return
        }

        let savedPIN = rememberHardwarePinEnabled ? PINVaultService.load() : nil
        restoreTravelVault(hardwarePIN: savedPIN)
    }

    private func restoreTravelVault(hardwarePIN: String?) {
        guard !isBusy else { return }
        guard let package = pendingRestorePackage, !package.tokens.isEmpty else { return }

        isBusy = true
        progressMessage = String(localized: "正在恢复到当前设备…")

        Task { @MainActor in
            do {
                let importedCount = try await tokenStore.importTravelVaultTokens(package.tokens, hardwarePIN: hardwarePIN)
                pendingRestorePackage = nil
                pendingRestoreGuidance = nil
                pendingRestoreSourceName = nil
                downloadedExpiresAt = nil
                pickupCodeInput = ""
                recoveryKeyInput = ""
                mode = .backup
                infoMessage = String(format: String(localized: "已恢复 %lld 个令牌到当前设备。"), importedCount)
            } catch {
                errorMessage = error.localizedDescription
            }

            isBusy = false
            progressMessage = nil
        }
    }

    private func handlePendingHardwarePINSubmission() {
        defer {
            pendingHardwarePINSubmission = nil
            hardwarePINContext = nil
        }

        guard let pin = pendingHardwarePINSubmission else {
            return
        }

        switch hardwarePINContext {
        case .restore:
            restoreTravelVault(hardwarePIN: pin)
        case nil:
            break
        }
    }

    private var canDownload: Bool {
        !TravelVaultCryptoService.normalizePickupCode(pickupCodeInput).isEmpty
            && !recoveryKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hardwarePINSubtitle: String {
        switch hardwarePINContext {
        case .restore:
            return String(localized: "恢复内容中包含需要重新创建的旧版通用硬件密钥副本，导入时需要硬件密钥PIN。")
        case nil:
            return String(localized: "请输入硬件密钥PIN。")
        }
    }
}
