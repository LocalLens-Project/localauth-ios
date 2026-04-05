import SwiftUI
import CoreImage.CIFilterBuiltins

struct PeerSyncView: View {
    var tokenStore: TokenStore

    @Environment(\.dismiss) private var dismiss
    @AppStorage("rememberHardwarePinEnabled") private var rememberHardwarePinEnabled = false

    @State private var syncService = PeerSyncService()
    @State private var isSendMode = true
    @State private var inputCode = ""
    @State private var pendingImportItems: [TokenTransferItem] = []
    @State private var pendingImportGuidance: TokenImportGuidance?
    @State private var showImportGuideSheet = false
    @State private var showHardwarePINPrompt = false
    @State private var errorMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Picker("", selection: $isSendMode) {
                        Text(String(localized: "发送")).tag(true)
                        Text(String(localized: "接收")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isSendMode {
                        sendModeView
                    } else {
                        receiveModeView
                    }

                    Spacer()

                    statusView
                }
                .padding(.top, 20)
            }
            .navigationTitle(String(localized: "局域网同步"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "关闭")) {
                        syncService.stop()
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .onDisappear {
                syncService.stop()
            }
            .sheet(isPresented: $showImportGuideSheet) {
                importGuideSheet
            }
            .sheet(isPresented: $showHardwarePINPrompt) {
                HardwarePINPromptView(
                    title: String(localized: "输入硬件密钥PIN"),
                    subtitle: String(localized: "本次同步包含通用硬件密钥令牌，创建 hmac-secret 凭据时需要验证PIN。"),
                    requiresConfirmation: false,
                    confirmTitle: String(localized: "开始导入")
                ) { pin in
                    performImport(hardwarePIN: pin)
                } onCancel: {
                }
            }
            .alert(String(localized: "同步失败"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button(String(localized: "确定"), role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Send Mode / 发送模式

    private var sendModeView: some View {
        VStack(spacing: 20) {
            if syncService.mode == .idle {
                Button {
                    syncService.startAdvertising()
                } label: {
                    Label(String(localized: "开始广播"), systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)

                Text(String(localized: "对方设备需输入配对码来连接"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
            } else {
                if let qrImage = generateQRCode(from: syncService.pairingCode) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text(String(localized: "配对码"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))

                Text(syncService.pairingCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .tracking(8)

                if case .connected = syncService.state {
                    Button {
                        sendTokens()
                    } label: {
                        Label(String(localized: "发送令牌"), systemImage: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
    }

    // MARK: - Receive Mode / 接收模式

    private var receiveModeView: some View {
        VStack(spacing: 20) {
            if syncService.mode == .idle {
                Text(String(localized: "输入对方设备上显示的配对码"))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))

                TextField("000000", text: $inputCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .frame(width: 200)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    configureImportHandler()
                    syncService.startBrowsing(withCode: inputCode)
                } label: {
                    Text(String(localized: "连接"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(inputCode.count == 6 ? Color.cyan : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(inputCode.count != 6)
                .padding(.horizontal, 40)
            } else {
                ProgressView()
                    .tint(.cyan)
                    .scaleEffect(1.5)
                Text(String(localized: "正在搜索..."))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Status / 状态

    @ViewBuilder
    private var statusView: some View {
        switch syncService.state {
        case .idle:
            EmptyView()
        case .waitingForPeer:
            HStack(spacing: 8) {
                ProgressView().tint(.cyan)
                Text(String(localized: "等待对方设备..."))
                    .foregroundColor(.white.opacity(0.5))
            }
        case .negotiating(let name):
            HStack(spacing: 8) {
                ProgressView().tint(.cyan)
                Text(String(format: String(localized: "正在与 %@ 建立安全通道..."), name))
                    .foregroundColor(.white.opacity(0.5))
            }
        case .connected(let name):
            Label(
                String(format: String(localized: "已连接：%@"), name),
                systemImage: "checkmark.circle.fill"
            )
            .foregroundColor(.green)
        case .transferring:
            HStack(spacing: 8) {
                ProgressView().tint(.cyan)
                Text(String(localized: "传输中..."))
                    .foregroundColor(.white.opacity(0.5))
            }
        case .completed(let count):
            Label(
                String(format: String(localized: "完成，已同步 %lld 个令牌"), count),
                systemImage: "checkmark.circle.fill"
            )
            .foregroundColor(.green)
        case .failed(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }

    // MARK: - Import Guidance / 导入引导

    private var importGuideSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(String(localized: "导入前确认"))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        if let guidance = pendingImportGuidance {
                            summaryRow(
                                title: String(localized: "待导入令牌"),
                                value: String(guidance.totalCount)
                            )

                            if guidance.confidentialCount > 0 {
                                infoCard(
                                    icon: "sensor.tag.radiowaves.forward",
                                    title: String(localized: "包含 YubiKey 机密级令牌"),
                                    body: String(localized: "导入过程中需要逐个完成挑战响应，请将 YubiKey 靠近手机并保持连接。")
                                )
                            }

                            if guidance.hardwareFIDOCount > 0 {
                                infoCard(
                                    icon: "key.horizontal.fill",
                                    title: String(localized: "包含通用硬件密钥令牌"),
                                    body: String(localized: "导入过程中需要为每个令牌创建 hmac-secret 凭据。请保持兼容硬件密钥连接，并准备输入 PIN。")
                                )
                            }

                            if !guidance.hasHighSecurityTokens {
                                infoCard(
                                    icon: "checkmark.shield",
                                    title: String(localized: "均为普通级令牌"),
                                    body: String(localized: "这些令牌将在本机通过生物识别路径重新建立加密材料。")
                                )
                            }
                        }

                        Text(String(localized: "导入会在当前设备重新创建本地加密材料，不会直接复用发送端的密文。"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.58))
                            .lineSpacing(3)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(String(localized: "同步确认"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) {
                        pendingImportItems = []
                        pendingImportGuidance = nil
                        showImportGuideSheet = false
                    }
                    .foregroundColor(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "开始导入")) {
                        beginImportFlow()
                    }
                    .foregroundColor(.cyan)
                    .disabled(isImporting || pendingImportItems.isEmpty)
                }
            }
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.65))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func infoCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(body)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func beginImportFlow() {
        if let guidance = pendingImportGuidance,
           guidance.hardwareFIDOCount > 0,
           (!rememberHardwarePinEnabled || (PINVaultService.load()?.isEmpty ?? true)) {
            showHardwarePINPrompt = true
            return
        }

        let savedPIN = rememberHardwarePinEnabled ? PINVaultService.load() : nil
        performImport(hardwarePIN: savedPIN)
    }

    private func performImport(hardwarePIN: String?) {
        isImporting = true
        let items = pendingImportItems

        Task {
            do {
                let importedCount = try await tokenStore.importTokens(items, hardwarePIN: hardwarePIN)
                await MainActor.run {
                    isImporting = false
                    pendingImportItems = []
                    pendingImportGuidance = nil
                    showImportGuideSheet = false
                    syncService.state = .completed(importedCount)
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func configureImportHandler() {
        syncService.onDataReceived = { data in
            Task { @MainActor in
                do {
                    let items = try tokenStore.parseImportPayload(from: data)
                    let guidance = tokenStore.guidance(for: items)
                    pendingImportItems = items
                    pendingImportGuidance = guidance
                    showImportGuideSheet = true
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Helpers / 辅助

    private func sendTokens() {
        do {
            let data = try tokenStore.exportTokens()
            try syncService.sendData(data)
            syncService.state = .completed(tokenStore.tokens.filter { $0.decryptedSecret != nil }.count)
        } catch {
            errorMessage = error.localizedDescription
            syncService.state = .failed(String(localized: "发送失败"))
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
