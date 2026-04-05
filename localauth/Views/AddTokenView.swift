import SwiftUI

struct AddTokenView: View {
    @Environment(\.dismiss) private var dismiss
    var tokenStore: TokenStore

    @State private var issuer = ""
    @State private var account = ""
    @State private var secretBase32 = ""
    @State private var digitsText = "6"
    @State private var periodText = "30"
    @State private var selectedAlgorithm: TokenAlgorithm = .sha1
    @State private var selectedTier: TokenTier = .normal
    @State private var selectedIcon = "key.fill"
    @State private var selectedColorHex = "007AFF"
    @State private var secretError: String?
    @State private var digitsError: String?
    @State private var periodError: String?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showHardwarePINPrompt = false
    @State private var pendingHardwarePINSubmission: String?
    @AppStorage("rememberHardwarePinEnabled") private var rememberHardwarePinEnabled = false

    private let iconOptions = [
        "key.fill", "terminal.fill", "envelope.fill", "globe",
        "server.rack", "icloud.fill", "bitcoinsign.circle.fill",
        "creditcard.fill", "building.2.fill", "gamecontroller.fill",
        "cart.fill", "heart.fill", "shield.fill", "lock.fill",
        "person.fill", "star.fill",
    ]

    private let colorOptions: [(name: String, hex: String)] = [
        (String(localized: "蓝"), "007AFF"), (String(localized: "青"), "00D4FF"), (String(localized: "绿"), "34C759"),
        (String(localized: "橙"), "FF9500"), (String(localized: "红"), "FF3B30"), (String(localized: "紫"), "AF52DE"),
        (String(localized: "黄"), "FFD60A"), (String(localized: "灰"), "8E8E93"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Issuer field / 签发方字段
                        fieldSection(title: String(localized: "签发方")) {
                            TextField(String(localized: "例如：GitHub"), text: $issuer)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Account field / 账号字段
                        fieldSection(title: String(localized: "账号")) {
                            TextField(String(localized: "例如：user@example.com"), text: $account)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Secret field / 密钥字段
                        fieldSection(title: String(localized: "密钥 (Base32)")) {
                            TextField("JBSWY3DPEHPK3PXP", text: $secretBase32)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .autocapitalization(.allCharacters)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onChange(of: secretBase32) { _, newValue in
                                    validateSecret(newValue)
                                }

                            if let secretError {
                                Text(secretError)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }

                        fieldSection(title: String(localized: "OTP 参数")) {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(String(localized: "位数"))
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.55))
                                        TextField("6", text: $digitsText)
                                            .keyboardType(.numberPad)
                                            .textFieldStyle(.plain)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onChange(of: digitsText) { _, newValue in
                                                validateDigits(newValue)
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(String(localized: "周期（秒）"))
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.55))
                                        TextField("30", text: $periodText)
                                            .keyboardType(.numberPad)
                                            .textFieldStyle(.plain)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onChange(of: periodText) { _, newValue in
                                                validatePeriod(newValue)
                                            }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(String(localized: "算法"))
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.55))
                                    Picker("", selection: $selectedAlgorithm) {
                                        ForEach(TokenAlgorithm.allCases, id: \.self) { algorithm in
                                            Text(algorithm.rawValue).tag(algorithm)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }

                                if let digitsError {
                                    Text(digitsError)
                                        .font(.system(size: 12))
                                        .foregroundColor(.red.opacity(0.8))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if let periodError {
                                    Text(periodError)
                                        .font(.system(size: 12))
                                        .foregroundColor(.red.opacity(0.8))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        // Protection tier selector / 防护级别选择器
                        fieldSection(title: String(localized: "防护级别")) {
                            Picker("", selection: $selectedTier) {
                                Label(String(localized: "生物识别"), systemImage: "faceid")
                                    .tag(TokenTier.normal)
                                Label(String(localized: "YubiKit 通道"), systemImage: "sensor.tag.radiowaves.forward")
                                    .tag(TokenTier.confidential)
                                Label(String(localized: "硬件密钥通用解锁通道"), systemImage: "key.horizontal.fill")
                                    .tag(TokenTier.hardwareFIDO)
                            }
                            .pickerStyle(.segmented)
                        }

                        // Icon picker / 图标选择
                        fieldSection(title: String(localized: "图标")) {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedIcon == icon ? .cyan : .white.opacity(0.5))
                                        .frame(width: 36, height: 36)
                                        .background(selectedIcon == icon ? Color.cyan.opacity(0.15) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onTapGesture { selectedIcon = icon }
                                }
                            }
                        }

                        // Color picker / 颜色选择
                        fieldSection(title: String(localized: "颜色")) {
                            HStack(spacing: 12) {
                                ForEach(colorOptions, id: \.hex) { option in
                                    Circle()
                                        .fill(Color(hex: option.hex))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColorHex == option.hex ? 2 : 0)
                                        )
                                        .onTapGesture { selectedColorHex = option.hex }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(String(localized: "添加令牌"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundColor(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "保存")) { saveToken() }
                        .foregroundColor(.cyan)
                        .disabled(!canSave)
                }
            }
            .alert(String(localized: "保存失败"), isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button(String(localized: "确定"), role: .cancel) {
                    saveError = nil
                }
            } message: {
                Text(saveError ?? "")
            }
            .sheet(isPresented: $showHardwarePINPrompt, onDismiss: resumeHardwareFIDOSaveIfNeeded) {
                HardwarePINPromptView(
                    title: String(localized: "输入硬件密钥PIN"),
                    subtitle: String(localized: "需要验证PIN才能创建通用硬件密钥令牌。"),
                    requiresConfirmation: false,
                    confirmTitle: String(localized: "继续")
                ) { pin in
                    pendingHardwarePINSubmission = pin
                } onCancel: {
                    pendingHardwarePINSubmission = nil
                }
            }
        }
    }

    private var canSave: Bool {
        !issuer.isEmpty
            && !account.isEmpty
            && !secretBase32.isEmpty
            && secretError == nil
            && digitsError == nil
            && periodError == nil
            && !isSaving
    }

    private func validateSecret(_ value: String) {
        let cleaned = value.uppercased().filter { $0 != " " && $0 != "-" && $0 != "=" }
        if cleaned.isEmpty {
            secretError = nil
            return
        }
        let valid = cleaned.allSatisfy { "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".contains($0) }
        secretError = valid ? nil : String(localized: "包含无效字符，Base32 仅允许 A-Z 和 2-7")
    }

    private func validateDigits(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            digitsError = String(localized: "验证码位数不能为空。")
            return
        }
        guard let digits = Int(normalized), digits > 0, digits <= 10 else {
            digitsError = String(localized: "验证码位数必须是 1 到 10 之间的整数。")
            return
        }
        digitsError = nil
    }

    private func validatePeriod(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            periodError = String(localized: "周期不能为空。")
            return
        }
        guard let period = Int(normalized), period > 0 else {
            periodError = String(localized: "周期必须是大于 0 的整数秒。")
            return
        }
        periodError = nil
    }

    private func saveToken() {
        validateSecret(secretBase32)
        validateDigits(digitsText)
        validatePeriod(periodText)
        guard canSave else { return }

        if selectedTier == .hardwareFIDO {
            if rememberHardwarePinEnabled, let savedPIN = PINVaultService.load(), !savedPIN.isEmpty {
                performSave(hardwarePIN: savedPIN)
            } else {
                prepareHardwareFIDOPINEntry()
            }
            return
        }

        performSave(hardwarePIN: nil)
    }

    private func prepareHardwareFIDOPINEntry() {
        guard !isSaving else { return }

        isSaving = true
        Task {
            do {
                try await tokenStore.probeHardwareFIDOAuthenticator()
                await MainActor.run {
                    isSaving = false
                    showHardwarePINPrompt = true
                }
            } catch {
                print("❌ 硬件密钥预检失败: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }

    private func performSave(hardwarePIN: String?) {
        guard let digits = Int(digitsText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let period = Int(periodText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        isSaving = true
        Task {
            do {
                try await tokenStore.addToken(
                    issuer: issuer,
                    account: account,
                    secretBase32: secretBase32,
                    iconName: selectedIcon,
                    colorHex: selectedColorHex,
                    tier: selectedTier,
                    digits: digits,
                    period: period,
                    algorithm: selectedAlgorithm,
                    hardwarePIN: hardwarePIN
                )
                dismiss()
            } catch {
                print("❌ 保存令牌失败: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }

    private func resumeHardwareFIDOSaveIfNeeded() {
        guard let pin = pendingHardwarePINSubmission else {
            return
        }
        pendingHardwarePINSubmission = nil
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            performSave(hardwarePIN: pin)
        }
    }

    @ViewBuilder
    private func fieldSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            content()
        }
    }
}

// MARK: - Color Hex Extension / Color hex 扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
