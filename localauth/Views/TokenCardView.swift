import SwiftUI

struct TokenCardView: View {
    var token: TokenModel
    var tokenStore: TokenStore

    @State private var isCopied = false
    @State private var scale: CGFloat = 1.0
    @State private var unlockRefreshToken = UUID()
    @State private var showHardwarePINPrompt = false
    @State private var pendingHardwarePINSubmission: String?
    @State private var unlockError: String?
    @State private var isUnlocking = false
    @AppStorage("rememberHardwarePinEnabled") private var rememberHardwarePinEnabled = false

    private var isUnlocked: Bool {
        token.decryptedSecret != nil
    }

    private var displayCode: String {
        if let code = tokenStore.decryptedCodes[token.id] {
            // Insert a visual spacer, for example: 492 104 / 插入可读性空格，例如：492 104
            let mid = code.index(code.startIndex, offsetBy: code.count / 2)
            return "\(code[code.startIndex..<mid]) \(code[mid...])"
        }
        return "••• •••"
    }

    private var tokenColor: Color {
        Color(hex: token.colorHex)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left side: icon and countdown ring / 左侧：图标与倒计时圆环
            ZStack {
                CountdownRingView(
                    isUnlocked: isUnlocked,
                    tokenColor: tokenColor,
                    period: token.resolvedPeriod
                )

                Image(systemName: token.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(tokenColor)
            }

            // Center: text content / 中间：文本信息
            VStack(alignment: .leading, spacing: 6) {
                Text(token.issuer)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(token.account)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Right side: unlock button or OTP code / 右侧：解锁按钮或验证码
            ZStack {
                if !isUnlocked {
                    Button(action: { initiateUnlock() }) {
                        HStack(spacing: 4) {
                            Image(systemName: unlockIconName)
                            Text(String(localized: "解锁"))
                                .tracking(1)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .foregroundColor(.cyan)
                    }
                    .disabled(isUnlocking)
                } else {
                    Text(isCopied ? String(localized: "已复制") : displayCode)
                        .font(.system(size: isCopied ? 16 : 26, weight: .bold, design: .monospaced))
                        .foregroundColor(isCopied ? .green : .white)
                        .tracking(isCopied ? 4 : 2)
                        .frame(width: 130, alignment: .trailing)
                        .contentTransition(.numericText())
                        .privacySensitive()
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(scale)
        .onTapGesture {
            guard isUnlocked else { return }
            copyToClipboard()
        }
        .sheet(isPresented: $showHardwarePINPrompt, onDismiss: resumeHardwareFIDOUnlockIfNeeded) {
            HardwarePINPromptView(
                title: String(localized: "输入硬件密钥PIN"),
                subtitle: String(localized: "需要验证PIN才能使用硬件密钥解锁令牌。"),
                requiresConfirmation: false,
                confirmTitle: String(localized: "解锁")
            ) { pin in
                pendingHardwarePINSubmission = pin
            } onCancel: {
                pendingHardwarePINSubmission = nil
            }
        }
        .alert(String(localized: "解锁失败"), isPresented: Binding(get: { unlockError != nil }, set: { if !$0 { unlockError = nil } })) {
            Button(String(localized: "确定"), role: .cancel) {
                unlockError = nil
            }
        } message: {
            Text(unlockError ?? "")
        }
    }

    private func initiateUnlock() {
        guard !isUnlocking else { return }

        if token.tier == .hardwareFIDO {
            if rememberHardwarePinEnabled, let savedPIN = PINVaultService.load(), !savedPIN.isEmpty {
                unlock(with: savedPIN)
            } else {
                prepareHardwareFIDOPINEntry()
            }
        } else {
            unlock()
        }
    }

    private func prepareHardwareFIDOPINEntry() {
        isUnlocking = true
        Task {
            do {
                try await tokenStore.probeHardwareFIDOAuthenticator()
                await MainActor.run {
                    isUnlocking = false
                    showHardwarePINPrompt = true
                }
            } catch {
                print("❌ 硬件密钥预检失败: \(error.localizedDescription)")
                await MainActor.run {
                    isUnlocking = false
                    unlockError = error.localizedDescription
                }
            }
        }
    }

    private func unlock(with pin: String? = nil) {
        isUnlocking = true
        Task {
            do {
                switch token.tier {
                case .normal:
                    try await tokenStore.unlockNormalToken(token)
                case .confidential:
                    try await tokenStore.unlockConfidentialToken(token)
                case .hardwareFIDO:
                    try await tokenStore.unlockHardwareFIDOToken(token, pin: pin)
                }
                await MainActor.run {
                    isCopied = false
                    isUnlocking = false
                    unlockRefreshToken = UUID()
                }
            } catch {
                print("❌ 解锁失败: \(error.localizedDescription)")
                await MainActor.run {
                    isUnlocking = false
                    unlockError = error.localizedDescription
                }
            }
        }
    }

    private func resumeHardwareFIDOUnlockIfNeeded() {
        guard let pin = pendingHardwarePINSubmission else {
            return
        }
        pendingHardwarePINSubmission = nil
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            unlock(with: pin)
        }
    }

    private var unlockIconName: String {
        switch token.tier {
        case .normal:
            return "faceid"
        case .confidential:
            return "sensor.tag.radiowaves.forward"
        case .hardwareFIDO:
            return "key.horizontal.fill"
        }
    }

    private func copyToClipboard() {
        guard let code = tokenStore.decryptedCodes[token.id] else { return }
        UIPasteboard.general.string = code

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            scale = 0.95
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 1.0
                isCopied = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut) {
                isCopied = false
            }
        }
    }
}

private struct CountdownRingView: View {
    let isUnlocked: Bool
    let tokenColor: Color
    let period: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
            let progress = isUnlocked ? TOTPGenerator.progress(time: context.date, period: period) : 0
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(tokenColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}
