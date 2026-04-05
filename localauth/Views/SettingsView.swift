import SwiftUI
import UIKit

// MARK: - 1. Data Models / 1. 数据模型
enum SettingDestination {
    case url(String)
    case aboutView
    case thirdPartyLicenses
    case yubiKeyGuide
    case none
}

struct SettingItem: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let iconColor: Color
    let isExternalLink: Bool
    let destination: SettingDestination
}

// MARK: - 2. Main View / 2. 主视图
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    
    @State private var showAbout = false
    @State private var showThirdPartyLicenses = false
    @State private var showYubiKeyGuide = false
    @State private var currentLang = AppLanguage.current
    @State private var isEmailCopied = false
    @State private var showEnablePINSheet = false
    @State private var showChangePINSheet = false
    @State private var pinErrorMessage: String?
    @AppStorage("rememberHardwarePinEnabled") private var rememberHardwarePinEnabled = false
    
    var strings: SettingsStrings {
        SettingsStrings.get(for: currentLang)
    }
    
    // Brand color / 品牌色
    let brandColor = Color(red: 6/255, green: 182/255, blue: 212/255)
    let supportEmail = OpenSourceProjectInfo.supportEmail
    
    // Section data / 分组数据
    var aboutItems: [SettingItem] {
        [
            SettingItem(
                title: String(localized: "关于我们"),
                iconName: "info.circle.fill",
                iconColor: .cyan,
                isExternalLink: false,
                destination: .aboutView
            ),
            SettingItem(
                title: String(localized: "YubiKey配置教程"),
                iconName: "sensor.tag.radiowaves.forward",
                iconColor: .orange,
                isExternalLink: false,
                destination: .yubiKeyGuide
            ),
            SettingItem(
                title: strings.repositoryLinkTitle,
                iconName: "chevron.left.forwardslash.chevron.right",
                iconColor: .red,
                isExternalLink: true,
                destination: .url(OpenSourceProjectInfo.repositoryURLString)
            ),
            SettingItem(
                title: strings.hardwareCompatibilityTitle,
                iconName: "list.bullet.rectangle.portrait",
                iconColor: .green,
                isExternalLink: true,
                destination: .url(OpenSourceProjectInfo.hardwareKeyCompatibilityURLString)
            )
        ]
    }
    
    var supportItems: [SettingItem] {
        [
            SettingItem(
                title: strings.documentationTitle,
                iconName: "book.pages.fill",
                iconColor: .blue,
                isExternalLink: true,
                destination: .url(OpenSourceProjectInfo.documentationURLString)
            ),
            SettingItem(
                title: strings.issueTrackerTitle,
                iconName: "bubble.left.and.exclamationmark.bubble.right.fill",
                iconColor: .purple,
                isExternalLink: true,
                destination: .url(OpenSourceProjectInfo.issueTrackerURLString)
            ),
            SettingItem(
                title: String(localized: "第三方许可"),
                iconName: "doc.text.magnifyingglass",
                iconColor: .teal,
                isExternalLink: false,
                destination: .thirdPartyLicenses
            )
        ]
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: SupportLocalAuthView(currentLang: $currentLang, brandColor: brandColor)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "books.vertical.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Text(strings.supportUs)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    NavigationLink(destination: AppIconSelectionView(currentLang: $currentLang, brandColor: brandColor)) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.purple)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "app.badge.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Text(strings.changeIcon)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }

                Section(String(localized: "硬件密钥PIN")) {
                    Toggle(String(localized: "记住PIN"), isOn: Binding(
                        get: { rememberHardwarePinEnabled },
                        set: { newValue in
                            if newValue {
                                showEnablePINSheet = true
                            } else {
                                rememberHardwarePinEnabled = false
                                PINVaultService.delete()
                            }
                        }
                    ))
                    .tint(brandColor)
                    .listRowBackground(Color.white.opacity(0.06))

                    if rememberHardwarePinEnabled {
                        Button(String(localized: "修改PIN")) {
                            showChangePINSheet = true
                        }
                        .foregroundColor(.white)
                        .listRowBackground(Color.white.opacity(0.06))

                        Button(String(localized: "关闭并清除PIN"), role: .destructive) {
                            rememberHardwarePinEnabled = false
                            PINVaultService.delete()
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }

                    Text(String(localized: "记住PIN后，添加和使用通用硬件密钥通道时可免去重复输入，PIN仅存储在本机Keychain中。"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Color.white.opacity(0.06))
                }
                
                // First section: about and product links / 第一组：关于与产品
                Section {
                    ForEach(aboutItems) { item in
                        SettingsRow(item: item) {
                            handleAction(for: item)
                        }
                    }
                }
                
                // Second section: support and legal links / 第二组：支持与法律
                Section {
                    ForEach(supportItems) { item in
                        SettingsRow(item: item) {
                            handleAction(for: item)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.green)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(strings.contactEmail)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white)
                                Button(action: {
                                    UIPasteboard.general.string = supportEmail
                                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                                    feedbackGenerator.prepare()
                                    feedbackGenerator.impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        isEmailCopied = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            isEmailCopied = false
                                        }
                                    }
                                }) {
                                    Text(supportEmail)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text(isEmailCopied ? strings.contactEmailCopied : strings.contactEmailTapHint)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isEmailCopied ? brandColor : .white.opacity(0.45))
                        Text(strings.contactEmailTip)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.white.opacity(0.06))
                    .listRowSeparatorTint(.white.opacity(0.1))
                } footer: {
                    VStack(spacing: 6) {
                        Text(strings.footerPrivacy)
                            .font(.system(size: 10, weight: .light))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                            .padding(.horizontal, 20)
                        if let translationNotice = strings.translationNotice {
                            Text(translationNotice)
                                .font(.system(size: 10, weight: .light))
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)
                                .padding(.horizontal, 20)
                        }
                    }
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.05).ignoresSafeArea())

            .navigationTitle(strings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(white: 0.05), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(strings.done) {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(brandColor)
                }
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutView()
            }
            .navigationDestination(isPresented: $showThirdPartyLicenses) {
                ThirdPartyLicensesView()
            }
            .navigationDestination(isPresented: $showYubiKeyGuide) {
                YubiKeySetupModuleView(
                    finishTitle: String(localized: "完成"),
                    showsCancelHint: false
                ) {
                    showYubiKeyGuide = false
                }
                .navigationTitle(String(localized: "YubiKey配置教程"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                currentLang = AppLanguage.current
                if rememberHardwarePinEnabled && PINVaultService.load() == nil {
                    rememberHardwarePinEnabled = false
                }
            }
            .sheet(isPresented: $showEnablePINSheet) {
                HardwarePINPromptView(
                    title: String(localized: "开启记住PIN"),
                    subtitle: String(localized: "请连续输入两次PIN。开启后将永久保存到本机Keychain，可在设置里随时修改或关闭。"),
                    requiresConfirmation: true,
                    confirmTitle: String(localized: "保存")
                ) { pin in
                    do {
                        try PINVaultService.save(pin: pin)
                        rememberHardwarePinEnabled = true
                    } catch {
                        pinErrorMessage = error.localizedDescription
                        rememberHardwarePinEnabled = false
                    }
                } onCancel: {
                    rememberHardwarePinEnabled = false
                }
            }
            .sheet(isPresented: $showChangePINSheet) {
                HardwarePINPromptView(
                    title: String(localized: "修改PIN"),
                    subtitle: String(localized: "请输入两次新PIN，新值将覆盖现有PIN。"),
                    requiresConfirmation: true,
                    confirmTitle: String(localized: "保存")
                ) { pin in
                    do {
                        try PINVaultService.save(pin: pin)
                    } catch {
                        pinErrorMessage = error.localizedDescription
                    }
                } onCancel: {
                }
            }
            .alert(String(localized: "保存失败"), isPresented: Binding(
                get: { pinErrorMessage != nil },
                set: { if !$0 { pinErrorMessage = nil } }
            )) {
                Button(String(localized: "确定"), role: .cancel) {
                    pinErrorMessage = nil
                }
            } message: {
                Text(pinErrorMessage ?? "")
            }
        }
    }
    
    private func handleAction(for item: SettingItem) {
        switch item.destination {
        case .url(let urlString):
            if let url = URL(string: urlString) {
                openURL(url)
            }
        case .aboutView:
            showAbout = true
        case .thirdPartyLicenses:
            showThirdPartyLicenses = true
        case .yubiKeyGuide:
            showYubiKeyGuide = true
        case .none:
            break
        }
    }
}

// MARK: - 3. Reusable Row Component / 3. 每一行的重用组件
struct SettingsRow: View {
    let item: SettingItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(item.iconColor)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: item.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(item.title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                
                Spacer()
                
                switch item.destination {
                case .none:
                    EmptyView()
                default:
                    if item.isExternalLink {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white.opacity(0.06))
        .listRowSeparatorTint(.white.opacity(0.1))
    }
}

#Preview {
    SettingsView()
}
