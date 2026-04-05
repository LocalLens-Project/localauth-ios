import SwiftUI
import UIKit

struct OnboardingView: View {
    var onComplete: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var currentPage = 0
    @State private var yubiPathChoice: YubiPathChoice = .biometricOnly
    @State private var completionRoute: OnboardingCompletionRoute = .app
    @State private var showYubiSetupFlow = false
    @State private var showGenericKeyGuide = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color.blue.opacity(0.12))
                .blur(radius: 120)
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.cyan.opacity(0.08))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(x: 150, y: 200)

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    page1_Brand.tag(0)
                    page_Concept.tag(1)
                    page2_AddMethods.tag(2)
                    page3_UnlockCopy.tag(3)
                    page4_TwoTiers.tag(4)
                    page5_TravelVault.tag(5)
                    page6_Privacy.tag(6)
                    page7_OpenSourceAnnouncement.tag(7)
                    page8_YubiPathChoice.tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if currentPage < 8 {
                    OnboardingProgressBar(currentPage: currentPage, totalPages: 9)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showYubiSetupFlow) {
            NavigationStack {
                YubiKeySetupModuleView(
                    finishTitle: String(localized: "开始使用"),
                    showsCancelHint: true
                ) {
                    showYubiSetupFlow = false
                    onComplete()
                }
                .navigationTitle(String(localized: "YubiKey配置教程"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "返回")) {
                            showYubiSetupFlow = false
                        }
                        .foregroundColor(.cyan)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showGenericKeyGuide) {
            genericKeyGuidePage
        }
    }

    // MARK: - Page 1: Brand + Mock Card / 第 1 页：品牌 + 模拟卡片

    private var page1_Brand: some View {
        OnboardingPageContainer {
            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .blur(radius: 40)
                        .frame(width: 140, height: 140)

                    AppIconView(size: 120)
                }

                VStack(spacing: 12) {
                    Text(String(localized: "独揽令牌"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text(String(localized: "你的两步验证码，默认离线生成；\n旅行寄存时需联网，附近同步仅在局域网内直连"))
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                MockTokenCardView(progress: 0.7)
                    .padding(.horizontal, 20)
                    .modifier(SlideUpFadeIn())

                Spacer()

                SwipeHint()

                Spacer()
            }
        }
    }

    // MARK: - Page 1.5: Product Philosophy / 第 1.5 页：理念
    
    private var page_Concept: some View {
        OnboardingPageContainer {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .center, spacing: 32) {
                            VStack(spacing: 24) {
                                ConceptAnimatedIcon()
                                .padding(.top, 60)
                                
                                Text(String(localized: "独揽令牌的理念"))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .tracking(1.5)
                            }
                            
                            FlowLayout(spacing: 0, lineSpacing: 10) {
                                let tokens = ConceptNarrative.tokens()
                                ForEach(tokens, id: \.self) { token in
                                    switch token {
                                    case .text(let text, _):
                                        Text(text)
                                            .font(.system(size: 15, weight: .light))
                                            .foregroundColor(.white.opacity(0.75))
                                    case .keyword(let text, let delay, _):
                                        AnimatedKeyword(text: text, delay: delay, brandColor: .cyan)
                                    }
                                }
                            }
                            .frame(width: geo.size.width - 48, alignment: .leading)
                        }
                        .padding(.bottom, 60)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Page 2: Three Ways to Add Tokens / 第 2 页：三种添加方式

    private var page2_AddMethods: some View {
        OnboardingPageContainer {
            VStack(spacing: 28) {
                Spacer()

                AnimatedHeaderIcon(symbol: "plus.circle.fill", tint: .cyan)

                VStack(spacing: 12) {
                    Text(String(localized: "三种方式，添加令牌"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(String(localized: "选择最适合你的方式"))
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                }

                VStack(spacing: 12) {
                    AddMethodCard(
                        icon: "qrcode.viewfinder",
                        color: .cyan,
                        title: String(localized: "扫描二维码"),
                        subtitle: String(localized: "对准网站上的二维码"),
                        delay: 0.0
                    )
                    AddMethodCard(
                        icon: "text.viewfinder",
                        color: .green,
                        title: String(localized: "截图识别"),
                        subtitle: String(localized: "从相册选取截图自动提取"),
                        delay: 0.1
                    )
                    AddMethodCard(
                        icon: "keyboard",
                        color: .orange,
                        title: String(localized: "手动输入"),
                        subtitle: String(localized: "直接输入 Base32 密钥"),
                        delay: 0.2
                    )
                }
                .padding(.horizontal, 20)

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - Page 3: Unlock and Copy Demo / 第 3 页：解锁与复制演示

    private var page3_UnlockCopy: some View {
        OnboardingPageContainer {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Text(String(localized: "点按解锁，轻触复制"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(String(localized: "验证码每 30 秒自动刷新"))
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                }

                MockTokenCardView(animatesCycle: true)
                    .padding(.horizontal, 20)

                HStack {
                    Label(String(localized: "面容解锁"), systemImage: "arrow.left")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))

                    Spacer()

                    Label(String(localized: "轻触复制"), systemImage: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - Page 4: Two Protection Paths / 第 4 页：两级防护

    private var page4_TwoTiers: some View {
        OnboardingPageContainer {
            VStack(spacing: 28) {
                Spacer()

                AnimatedHeaderIcon(symbol: "shield.lefthalf.filled.badge.checkmark", tint: .cyan)

                VStack(spacing: 12) {
                    Text(String(localized: "双通道硬件防护，按需选择"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 12) {
                    TierCard(
                        icon: "faceid",
                        color: .cyan,
                        title: String(localized: "Face ID 解锁"),
                        subtitle: String(localized: "适合大多数账号"),
                        label: String(localized: "普通级"),
                        delay: 0.0
                    )
                    TierCard(
                        icon: "sensor.tag.radiowaves.forward",
                        color: .orange,
                        title: String(localized: "YubiKey 专属通道"),
                        subtitle: String(localized: "保留 YubiKit 通道体验"),
                        label: String(localized: "机密级"),
                        delay: 0.15
                    )
                    TierCard(
                        icon: "key.horizontal.fill",
                        color: .green,
                        title: String(localized: "通用硬件密钥通道"),
                        subtitle: String(localized: "支持 NFC 的 CTAP2 hmac-secret 设备"),
                        label: String(localized: "机密级"),
                        delay: 0.3
                    )
                }
                .padding(.horizontal, 20)

                Text(String(localized: "若使用 Face ID 解锁，加密密钥存储在安全隔区芯片中，即使越狱也难以提取"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - Page 5: Travel Vault / 第 5 页：旅行寄存

    private var page5_TravelVault: some View {
        OnboardingPageContainer {
            VStack(spacing: 24) {
                Spacer()

                AnimatedHeaderIcon(symbol: "airplane.circle.fill", tint: .cyan)

                VStack(spacing: 12) {
                    Text(String(localized: "旅行寄存"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(String(localized: "旅行、过关或紧急清空前，你可以先上传一份临时旅行寄存密文，再清空本机令牌。"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    UpdateBulletCard(
                        icon: "lock.shield.fill",
                        color: .cyan,
                        text: String(localized: "旅行寄存密文全程端到端加密，服务器无法读取令牌内容。")
                    )
                    UpdateBulletCard(
                        icon: "globe.europe.africa.fill",
                        color: .mint,
                        text: OpenSourceProjectInfo.travelVaultDeploymentNotice
                    )
                    UpdateBulletCard(
                        icon: "wifi",
                        color: .green,
                        text: String(localized: "只有在你主动创建或下载旅行寄存时，应用才会联网；平时仍以本地使用为主。")
                    )
                    UpdateBulletCard(
                        icon: "hourglass",
                        color: .orange,
                        text: String(localized: "这是低频紧急功能。请勿滥用；重复创建会覆盖旧备份，过于频繁会被限流。")
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                SwipeHint()

                Spacer(minLength: 6)
            }
        }
    }

    // MARK: - Page 6: Privacy Promise / 第 6 页：隐私承诺

    private var page6_Privacy: some View {
        OnboardingPageContainer {
            VStack(spacing: 28) {
                Spacer()

                AnimatedHeaderIcon(symbol: "network.slash", tint: .green)

                VStack(spacing: 12) {
                    Text(String(localized: "隐私，是设计原则"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 16) {
                    PrivacyPoint(icon: "wifi.slash", text: String(localized: "核心令牌功能默认离线；仅旅行寄存在你主动使用时联网"))
                    PrivacyPoint(icon: "eye.slash", text: String(localized: "切出应用自动锁定，隐私遮罩即时覆盖"))
                    PrivacyPoint(icon: "arrow.triangle.2.circlepath", text: String(localized: "换机迁移通过局域网完成，不经服务器"))
                }
                .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Text(String(localized: "除了退出应用自动锁定，你还可以点击右上角锁按钮立即锁定全部令牌。"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.62))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LockAllDemoView()
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    private var page7_OpenSourceAnnouncement: some View {
        OnboardingPageContainer {
            OnboardingOpenSourceAnnouncementPage {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentPage = 8
                }
            }
        }
    }

    private var page8_YubiPathChoice: some View {
        OnboardingPageContainer {
            VStack(spacing: 24) {
                Spacer()

                AnimatedHeaderIcon(symbol: "sensor.tag.radiowaves.forward", tint: .orange)

                VStack(spacing: 12) {
                    Text(String(localized: "选择硬件密钥方案"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(String(localized: "请选择你的硬件密钥情况，我们会自动安排下一步。"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    yubiChoiceCard(
                        title: String(localized: "我没有硬件密钥"),
                        selected: yubiPathChoice == .biometricOnly
                    ) {
                        yubiPathChoice = .biometricOnly
                    }

                    yubiChoiceCard(
                        title: String(localized: "我有YubiKey NFC版本，开始教程"),
                        selected: yubiPathChoice == .yubiKeySetup
                    ) {
                        yubiPathChoice = .yubiKeySetup
                    }

                    yubiChoiceCard(
                        title: String(localized: "我有其他支持hmac-secret 扩展的硬件密钥"),
                        selected: yubiPathChoice == .genericHardwareKey
                    ) {
                        yubiPathChoice = .genericHardwareKey
                    }
                }
                .padding(.horizontal, 22)

                if yubiPathChoice == .biometricOnly {
                    Text(String(localized: "当您拥有YubiKey NFC版本时，可以到设置里点击“YubiKey配置教程”继续。"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 26)
                }

                Spacer()

                Button {
                    completeOnboardingFlow()
                } label: {
                    Text(continueButtonTitle)
                        .font(.system(size: 17, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)

                Spacer(minLength: 6)
            }
        }
        .onAppear {
            completionRoute = completionRoute(for: yubiPathChoice)
        }
    }

    private func yubiChoiceCard(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selected ? .cyan : .white.opacity(0.45))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(selected ? 0.10 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.cyan : Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var continueButtonTitle: String {
        switch completionRoute {
        case .app:
            return String(localized: "进入应用")
        case .yubiKeySetup:
            return String(localized: "开始教程")
        case .genericHardwareKey:
            return String(localized: "继续")
        }
    }

    private func completionRoute(for choice: YubiPathChoice) -> OnboardingCompletionRoute {
        switch choice {
        case .biometricOnly:
            return .app
        case .yubiKeySetup:
            return .yubiKeySetup
        case .genericHardwareKey:
            return .genericHardwareKey
        }
    }

    private func completeOnboardingFlow() {
        switch completionRoute {
        case .app:
            onComplete()
        case .yubiKeySetup:
            showYubiSetupFlow = true
        case .genericHardwareKey:
            showGenericKeyGuide = true
        }
    }

    private var genericKeyGuidePage: some View {
        OnboardingPageContainer {
            VStack(spacing: 28) {
                Spacer()

                AnimatedHeaderIcon(symbol: "key.horizontal.fill", tint: .green)

                Text(String(localized: "硬件密钥支持列表"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    if let url = URL(string: OpenSourceProjectInfo.hardwareKeyCompatibilityURLString) {
                        openURL(url)
                    }
                } label: {
                    Text(String(localized: "阅读支持列表"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 34)

                Spacer()

                Button {
                    showGenericKeyGuide = false
                    onComplete()
                } label: {
                    Text(String(localized: "进入应用"))
                        .font(.system(size: 17, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)

                Spacer(minLength: 6)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

private enum YubiPathChoice {
    case biometricOnly
    case yubiKeySetup
    case genericHardwareKey
}

private enum OnboardingCompletionRoute {
    case app
    case yubiKeySetup
    case genericHardwareKey
}

private struct AnimatedHeaderIcon: View {
    let symbol: String
    let tint: Color

    @State private var beat = 0

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(tint)
            .symbolEffect(.bounce, value: beat)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
            .shadow(color: tint.opacity(0.32), radius: 8, y: 4)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.1))
                await MainActor.run {
                    beat += 1
                }
            }
        }
    }
}

private struct ConceptAnimatedIcon: View {
    @State private var beat = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "square.3.layers.3d.down.right")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.cyan)
                .symbolEffect(.bounce, value: beat)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
                .shadow(color: .cyan.opacity(0.35), radius: 8, y: 4)

            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundColor(.cyan)
                .padding(4)
                .background(Circle().fill(Color.black))
                .symbolEffect(.pulse, options: .repeating, isActive: true)
                .offset(x: 4, y: 4)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    beat += 1
                }
            }
        }
    }
}

// MARK: - Page Container / 页面容器

private struct OnboardingPageContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.bottom, 40)
    }
}

// MARK: - Add-Method Card / 添加方式小卡片

private struct AddMethodCard: View {
    var icon: String
    var color: Color
    var title: String
    var subtitle: String
    var delay: Double

    @State private var appeared = false
    @State private var iconBeat = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 36)
                .symbolEffect(.bounce, value: iconBeat)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                ),
                    lineWidth: 0.5
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                appeared = true
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(0.25 + delay))
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.15))
                await MainActor.run {
                    iconBeat += 1
                }
            }
        }
    }
}

// MARK: - Tier Comparison Card / 防护等级对比卡片

private struct TierCard: View {
    var icon: String
    var color: Color
    var title: String
    var subtitle: String
    var label: String
    var delay: Double

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(color == .orange ? 0.4 : 0.15), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: color == .orange ? 1 : 0.5
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Privacy Bullet Row / 隐私要点行

private struct PrivacyPoint: View {
    var icon: String
    var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 28)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(2)
        }
    }
}

private struct UpdateBulletCard: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.78))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 0.8)
        )
    }
}

private struct LockAllDemoView: View {
    private enum Phase {
        case normal
        case focus
        case feedback
    }

    @State private var phase: Phase = .normal

    private var isFocused: Bool {
        phase != .normal
    }

    private var showsFeedback: Bool {
        phase == .feedback
    }

    private var lockFeedbackText: String {
        String(localized: "已全部锁定")
    }

    private var lockFeedbackExpandedWidth: CGFloat {
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let textWidth = (lockFeedbackText as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + 12 + 8 + 44
    }

    var body: some View {
        HStack(spacing: 12) {
            demoTopButton(icon: "arrow.triangle.2.circlepath", tint: .cyan, emphasized: false)
            demoTopButton(icon: "gearshape", tint: .cyan, emphasized: false)
            Spacer(minLength: 0)
            lockFeedbackButton
            demoTopButton(icon: "plus", tint: .cyan, emphasized: false, iconSize: 20, weight: .bold)
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
        )
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: phase)
        .task {
            while !Task.isCancelled {
                await MainActor.run {
                    phase = .normal
                }
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        phase = .focus
                    }
                }
                try? await Task.sleep(for: .seconds(0.5))
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        phase = .feedback
                    }
                }
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        phase = .normal
                    }
                }
                try? await Task.sleep(for: .seconds(0.8))
            }
        }
    }

    private var lockFeedbackButton: some View {
        HStack(spacing: 0) {
            if showsFeedback {
                Text(lockFeedbackText)
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
                .scaleEffect(isFocused ? 1.08 : 1.0)
        }
        .frame(width: showsFeedback ? lockFeedbackExpandedWidth : 44, height: 44, alignment: .trailing)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(showsFeedback ? 0.10 : 0.0))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(showsFeedback ? 0.18 : 0.0), lineWidth: 1)
                )
        )
    }

    private func demoTopButton(icon: String, tint: Color, emphasized: Bool, iconSize: CGFloat = 18, weight: Font.Weight = .semibold) -> some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: weight))
            .foregroundStyle(tint.opacity(isFocused && !emphasized ? 0.42 : 0.95))
            .frame(width: 44, height: 44)
            .scaleEffect(isFocused && !emphasized ? 0.96 : 1.0)
    }
}
// MARK: - Swipe-Left Paging Hint / 向左滑动翻页提示

private struct SwipeHint: View {
    @State private var offsetX: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
            Text(String(localized: "向左滑动翻页"))
                .font(.system(size: 13))
        }
        .foregroundColor(.white.opacity(0.35))
        .offset(x: offsetX)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                offsetX = -8
            }
        }
    }
}

// MARK: - Bottom Step Progress Bar / 底部步骤进度条

private struct OnboardingProgressBar: View {
    var currentPage: Int
    var totalPages: Int

    private let labels = [String(localized: "欢迎"), String(localized: "理念"), String(localized: "添加"), String(localized: "使用"), String(localized: "防护"), String(localized: "旅行寄存"), String(localized: "隐私"), String(localized: "开源"), String(localized: "分流")]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalPages, id: \.self) { index in
                // Node and label / 节点与标签
                VStack(spacing: 6) {
                    Circle()
                        .fill(index <= currentPage ? Color.cyan : Color.white.opacity(0.2))
                        .frame(width: index == currentPage ? 10 : 7,
                               height: index == currentPage ? 10 : 7)
                        .shadow(color: index == currentPage ? .cyan.opacity(0.6) : .clear, radius: 4)

                    Text(labels[index])
                        .font(.system(size: 10, weight: index == currentPage ? .bold : .regular))
                        .foregroundColor(index <= currentPage ? .cyan : .white.opacity(0.3))
                }
                .frame(maxWidth: index == 0 || index == totalPages - 1 ? nil : .infinity)

                // Connecting line, except after the last node / 连接线，最后一个节点后不再绘制
                if index < totalPages - 1 {
                    Rectangle()
                        .fill(index < currentPage ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12))
                        .frame(height: 1.5)
                        .frame(maxWidth: .infinity)
                        .offset(y: -10) // Align with the dot center / 对齐到圆点中心
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }
}

// MARK: - Slide-Up Fade-In Modifier / 从底部淡入动画修饰器

private struct SlideUpFadeIn: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                    appeared = true
                }
            }
    }
}
