import SwiftUI
import UIKit

struct TokenListView: View {
    var tokenStore: TokenStore
    @AppStorage("rememberHardwarePinEnabled") private var rememberHardwarePinEnabled = false

    @State private var showAddSheet = false
    @State private var showQRScanner = false
    @State private var showOCRPicker = false
    @State private var showManualAdd = false
    @State private var showPeerSync = false
    @State private var showTravelVault = false
    @State private var showSettings = false
    @State private var scannedTokens: [ParsedToken] = []
    @State private var pendingTokens: [ParsedToken] = []
    @State private var showTierSelection = false
    @State private var showAppearanceStepInFlow = false
    @State private var selectedTierForPending: TokenTier = .normal
    @State private var selectedIconForPending = "key.fill"
    @State private var selectedColorHexForPending = "007AFF"
    @State private var tokenForAppearanceEdit: TokenModel?
    @State private var errorMessage: String?
    @State private var isProcessingAdd = false
    @State private var showLockAllFeedback = false
    @State private var lockAllFeedbackToken = UUID()
    @State private var showHardwarePINPrompt = false
    @State private var pendingIconAfterPIN = "key.fill"
    @State private var pendingColorAfterPIN = "007AFF"
    @State private var pendingHardwarePINSubmission: String?

    private var lockAllFeedbackText: String {
        String(localized: "已全部锁定")
    }

    private var lockAllFeedbackExpandedWidth: CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let textWidth = (lockAllFeedbackText as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + 12 + 8 + 44
    }

    var body: some View {
        NavigationStack {
            ZStack {
                immersiveBackground

                if tokenStore.tokens.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(tokenStore.tokens) { token in
                                TokenCardView(
                                    token: token,
                                    tokenStore: tokenStore
                                )
                                .contextMenu {
                                    if token.decryptedSecret != nil {
                                        Button {
                                            tokenStore.lockToken(token)
                                        } label: {
                                            Label(String(localized: "锁定"), systemImage: "lock.fill")
                                        }
                                    }
                                    Button {
                                        tokenForAppearanceEdit = token
                                    } label: {
                                        Label(String(localized: "修改图标和颜色"), systemImage: "paintbrush")
                                    }
                                    Button(role: .destructive) {
                                        tokenStore.deleteToken(token)
                                    } label: {
                                        Label(String(localized: "删除"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                headerBar
            }
            .onAppear {
                tokenStore.refreshCodes()
            }
            .sheet(isPresented: $showAddSheet) {
                if #available(iOS 16.0, *) {
                    AddTokenSheet(
                        onScan: { showQRScanner = true },
                        onImage: { showOCRPicker = true },
                        onManual: { showManualAdd = true }
                    )
                    .presentationDetents([.height(380)])
                    .presentationDragIndicator(.hidden)
                } else {
                    AddTokenSheet(
                        onScan: { showQRScanner = true },
                        onImage: { showOCRPicker = true },
                        onManual: { showManualAdd = true }
                    )
                }
            }
            .fullScreenCover(isPresented: $showQRScanner) {
                NavigationStack {
                    QRScannerView { code in
                        showQRScanner = false
                        handleScannedCode(code)
                    }
                    .ignoresSafeArea()
                    .navigationTitle(String(localized: "扫描二维码"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "取消")) { showQRScanner = false }
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
            .sheet(isPresented: $showOCRPicker) {
                OCRPickerView { secrets in
                    for secret in secrets {
                        handleScannedCode(secret)
                    }
                }
            }
            .sheet(isPresented: $showManualAdd) {
                AddTokenView(tokenStore: tokenStore)
            }
            .sheet(isPresented: $showPeerSync) {
                PeerSyncView(tokenStore: tokenStore)
            }
            .sheet(isPresented: $showTravelVault) {
                TravelVaultView(tokenStore: tokenStore)
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showTierSelection) {
                tierSelectionScreen
            }
            .sheet(item: $tokenForAppearanceEdit) { token in
                NavigationStack {
                    TokenAppearancePickerView(
                        title: String(localized: "修改图标和颜色"),
                        initialIconName: token.iconName,
                        initialColorHex: token.colorHex
                    ) { iconName, colorHex in
                        updateTokenAppearance(token: token, iconName: iconName, colorHex: colorHex)
                    }
                }
            }
            .sheet(isPresented: $showHardwarePINPrompt, onDismiss: resumePendingHardwareFIDOImportIfNeeded) {
                HardwarePINPromptView(
                    title: String(localized: "输入硬件密钥PIN"),
                    subtitle: String(localized: "PIN将用于当前令牌的FIDO hmac-secret通道初始化。"),
                    requiresConfirmation: false,
                    confirmTitle: String(localized: "确定")
                ) { pin in
                    pendingHardwarePINSubmission = pin
                } onCancel: {
                    pendingHardwarePINSubmission = nil
                }
            }
            .alert(String(localized: "添加失败"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button(String(localized: "确定"), role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    showPeerSync = true
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.cyan.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())

                Button {
                    showTravelVault = true
                } label: {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.cyan.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.cyan.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())

                Spacer()

                if !tokenStore.tokens.isEmpty {
                    Button {
                        lockAllWithFeedback()
                    } label: {
                        lockAllFeedbackButton
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.cyan.opacity(0.95))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .disabled(isProcessingAdd)
            }

            Text(String(localized: "独揽令牌"))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.06, blue: 0.11).opacity(0.95),
                    Color(red: 0.01, green: 0.03, blue: 0.07).opacity(0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blur(radius: 20)
        )
        .background(Color(red: 0.02, green: 0.04, blue: 0.08))
    }

    private var lockAllFeedbackButton: some View {
        HStack(spacing: 0) {
            if showLockAllFeedback {
                Text(lockAllFeedbackText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .transition(.opacity)
            }
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.9))
                .frame(width: 44, height: 44)
        }
        .frame(width: showLockAllFeedback ? lockAllFeedbackExpandedWidth : 44, height: 44, alignment: .trailing)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(showLockAllFeedback ? 0.08 : 0.0))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(showLockAllFeedback ? 0.16 : 0.0), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: showLockAllFeedback)
    }

    private func lockAllWithFeedback() {
        let hasUnlockedToken = tokenStore.tokens.contains { $0.decryptedSecret != nil }
        guard hasUnlockedToken else { return }

        tokenStore.lockAll()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        let token = UUID()
        lockAllFeedbackToken = token

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            showLockAllFeedback = true
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            guard lockAllFeedbackToken == token else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showLockAllFeedback = false
                }
            }
        }
    }

    private var immersiveBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.06, blue: 0.11),
                    Color(red: 0.01, green: 0.03, blue: 0.07),
                    Color(red: 0.01, green: 0.01, blue: 0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.22),
                    Color.cyan.opacity(0.04),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.24),
                    Color.blue.opacity(0.05),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 500
            )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.08),
                            Color.black.opacity(0.30)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan.opacity(0.84), .blue.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .cyan.opacity(0.28), radius: 18, y: 4)

            Text(String(localized: "还没有令牌"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Text(String(localized: "点击右上角 + 添加你的第一个令牌"))
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)

            Button {
                showTravelVault = true
            } label: {
                Label(String(localized: "恢复旅行寄存"), systemImage: "icloud.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 30)
    }

    private var tierSelectionScreen: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Button(String(localized: "取消")) {
                            pendingTokens = []
                            showAppearanceStepInFlow = false
                            showTierSelection = false
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)

                        Spacer()

                        Text(String(localized: "新令牌"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Text(String(localized: "取消")).opacity(0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 30)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "选择解锁方式"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text(String(localized: "二维码解析成功。请为该令牌配置所需的安全防护级别。"))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                    VStack(spacing: 16) {
                        MethodCard(
                            tier: .normal,
                            isSelected: selectedTierForPending == .normal,
                            brandColor: .cyan
                        ) {
                            selectMethod(.normal)
                        }

                        MethodCard(
                            tier: .confidential,
                            isSelected: selectedTierForPending == .confidential,
                            brandColor: .cyan
                        ) {
                            selectMethod(.confidential)
                        }

                        MethodCard(
                            tier: .hardwareFIDO,
                            isSelected: selectedTierForPending == .hardwareFIDO,
                            brandColor: .cyan
                        ) {
                            selectMethod(.hardwareFIDO)
                        }
                    }
                    .padding(.horizontal, 24)

                    Text(statusText(for: selectedTierForPending))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.top, 20)
                        .animation(.easeInOut, value: selectedTierForPending)

                    Spacer()

                    Button(action: {
                        showAppearanceStepInFlow = true
                    }) {
                        Text(String(localized: "继续创建令牌"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(white: 0.05))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.cyan)
                                    .shadow(color: Color.cyan.opacity(0.3), radius: 10, y: 4)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .navigationDestination(isPresented: $showAppearanceStepInFlow) {
                TokenAppearancePickerView(
                    title: String(localized: "图标与颜色"),
                    confirmTitle: String(localized: "创建"),
                    initialIconName: selectedIconForPending,
                    initialColorHex: selectedColorHexForPending,
                    autoDismissOnConfirm: false,
                    onCancel: { showAppearanceStepInFlow = false }
                ) { iconName, colorHex in
                    selectedIconForPending = iconName
                    selectedColorHexForPending = colorHex
                    createPendingTokensWithPINHandling(
                        tier: selectedTierForPending,
                        iconName: iconName,
                        colorHex: colorHex
                    )
                    showAppearanceStepInFlow = false
                    showTierSelection = false
                }
            }
        }
    }

    private func selectMethod(_ tier: TokenTier) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedTierForPending = tier
        }
    }

    private func statusText(for tier: TokenTier) -> String {
        switch tier {
        case .normal: return String(localized: "已选择生物识别解锁，可继续创建令牌")
        case .confidential: return String(localized: "已选择 YubiKit 通道，请确保您的 Yubikey 在身边")
        case .hardwareFIDO: return String(localized: "已选择硬件密钥通用解锁通道，请准备支持 CTAP2 hmac-secret 的设备")
        }
    }

    private func handleScannedCode(_ code: String) {
        Task {
            do {
                let parsed = try MigrationParser.parse(code)
                pendingTokens = parsed
                selectedTierForPending = .normal
                selectedIconForPending = "key.fill"
                selectedColorHexForPending = "007AFF"
                showAppearanceStepInFlow = false
                showTierSelection = true
            } catch {
                if (try? Base32.decode(code)) != nil {
                    showManualAdd = true
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func createPendingTokensWithPINHandling(tier: TokenTier, iconName: String, colorHex: String) {
        guard tier == .hardwareFIDO else {
            addPendingTokens(tier: tier, iconName: iconName, colorHex: colorHex, hardwarePIN: nil)
            return
        }
        if rememberHardwarePinEnabled, let pin = PINVaultService.load(), !pin.isEmpty {
            addPendingTokens(tier: tier, iconName: iconName, colorHex: colorHex, hardwarePIN: pin)
            return
        }
        pendingIconAfterPIN = iconName
        pendingColorAfterPIN = colorHex
        prepareHardwareFIDOPINEntryForPendingTokens()
    }

    private func prepareHardwareFIDOPINEntryForPendingTokens() {
        Task {
            do {
                try await tokenStore.probeHardwareFIDOAuthenticator()
                await MainActor.run {
                    showHardwarePINPrompt = true
                }
            } catch {
                print("❌ 硬件密钥预检失败: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func addPendingTokens(tier: TokenTier, iconName: String, colorHex: String, hardwarePIN: String?) {
        guard !isProcessingAdd else { return }
        isProcessingAdd = true
        let tokensToAdd = pendingTokens

        Task { @MainActor in
            defer {
                isProcessingAdd = false
            }

            for token in tokensToAdd {
                do {
                    try await tokenStore.addToken(
                        issuer: token.issuer,
                        account: token.account,
                        secretBase32: token.secretBase32,
                        iconName: iconName,
                        colorHex: colorHex,
                        tier: tier,
                        digits: token.digits,
                        period: token.period,
                        algorithm: token.algorithm,
                        hardwarePIN: hardwarePIN
                    )
                    
                    if tier == .hardwareFIDO || tier == .confidential {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                    }
                } catch {
                    print("❌ 添加令牌失败: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    break
                }
            }
            pendingTokens = []
        }
    }

    private func resumePendingHardwareFIDOImportIfNeeded() {
        guard let pin = pendingHardwarePINSubmission else {
            return
        }
        pendingHardwarePINSubmission = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            addPendingTokens(
                tier: selectedTierForPending,
                iconName: pendingIconAfterPIN,
                colorHex: pendingColorAfterPIN,
                hardwarePIN: pin
            )
            showTierSelection = false
        }
    }

    private func updateTokenAppearance(token: TokenModel, iconName: String, colorHex: String) {
        do {
            try tokenStore.updateTokenAppearance(token, iconName: iconName, colorHex: colorHex)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Method Card Component / 添加方式卡片组件

private struct MethodCard: View {
    let tier: TokenTier
    let isSelected: Bool
    let brandColor: Color
    let action: () -> Void
    
    @State private var tapCount = 0
    
    var body: some View {
        Button(action: {
            tapCount += 1
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(isSelected ? brandColor : .white.opacity(0.6))
                        .symbolEffect(.bounce, value: tapCount)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isSelected && (tier == .confidential || tier == .hardwareFIDO))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? brandColor.opacity(0.06) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? brandColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var title: String {
        switch tier {
        case .normal: return String(localized: "生物识别解锁")
        case .confidential: return String(localized: "YubiKit 通道")
        case .hardwareFIDO: return String(localized: "硬件密钥通用解锁通道")
        }
    }
    
    private var subtitle: String {
        switch tier {
        case .normal: return String(localized: "使用 Face ID / Touch ID 快速验证，日常使用更便捷。")
        case .confidential: return String(localized: "手机靠近 Yubikey 完成挑战响应，提升高级防护强度。")
        case .hardwareFIDO: return String(localized: "手机靠近支持 CTAP2 hmac-secret 的硬件密钥，通过 NFC 完成识别与通信。")
        }
    }
    
    private var iconName: String {
        switch tier {
        case .normal: return "faceid"
        case .confidential: return "sensor.tag.radiowaves.forward"
        case .hardwareFIDO: return "key.horizontal.fill"
        }
    }
}
