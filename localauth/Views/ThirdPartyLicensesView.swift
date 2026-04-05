import SwiftUI

// MARK: - Third-Party Licenses View / 第三方许可页面
struct ThirdPartyLicensesView: View {
    @Environment(\.openURL) private var openURL

    private let brandColor = Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255)
    private let repositoryURL = URL(string: "https://github.com/Yubico/yubikit-ios")!
    private let licenseURL = URL(string: "https://github.com/Yubico/yubikit-ios/blob/main/LICENSE")!

    var body: some View {
        List {
            Section {
                Text(String(localized: "本应用使用了以下第三方开源组件。"))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.78))
                    .padding(.vertical, 4)
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section {
                metadataRow(title: String(localized: "组件名称"), value: "YubiKit")
                metadataRow(
                    title: String(localized: "用途"),
                    value: String(localized: "Yubico 提供的 iOS SDK，用于通过 NFC 与 YubiKey 进行安全交互。"),
                    multiline: true
                )
                metadataRow(title: String(localized: "许可证"), value: "Apache 2.0")

                actionRow(
                    title: String(localized: "上游仓库"),
                    iconName: "arrow.up.right.square"
                ) {
                    openURL(repositoryURL)
                }

                actionRow(
                    title: String(localized: "查看许可证全文"),
                    iconName: "doc.text"
                ) {
                    openURL(licenseURL)
                }
            } header: {
                Text(String(localized: "第三方组件"))
            } footer: {
                Text(String(localized: "系统框架如 SwiftUI、CryptoKit 与 CoreNFC 由 Apple 提供，不在此列表中单独列出。"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(white: 0.05).ignoresSafeArea())
        .navigationTitle(String(localized: "第三方许可"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(white: 0.05), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Row Builders / 行构建器
    private func metadataRow(title: String, value: String, multiline: Bool = false) -> some View {
        HStack(alignment: multiline ? .top : .center, spacing: 16) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.62))
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: multiline)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.06))
    }

    private func actionRow(title: String, iconName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(brandColor)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white.opacity(0.06))
    }
}

#Preview {
    NavigationStack {
        ThirdPartyLicensesView()
    }
}
