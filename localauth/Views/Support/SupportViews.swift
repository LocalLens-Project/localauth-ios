import SwiftUI

// MARK: - Support Pages / 支持页面
struct SupportLocalAuthView: View {
    @Binding var currentLang: AppLanguage
    let brandColor: Color

    @Environment(\.openURL) private var openURL

    var strings: SupportPageStrings {
        SupportPageStrings.get(for: currentLang)
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(strings.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        Text(strings.subtitle)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.65))
                            .lineSpacing(4)
                    }
                    .padding(.top, 10)

                    SupportInfoCard(
                        title: strings.freeTitle,
                        message: strings.freeDescription,
                        accent: brandColor,
                        systemImage: "gift.fill"
                    )

                    SupportInfoCard(
                        title: strings.localTitle,
                        message: strings.localDescription,
                        accent: .green,
                        systemImage: "internaldrive.fill"
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(strings.projectsTitle)
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                        }

                        Text(strings.projectsDescription)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.55))
                            .lineSpacing(3)

                        VStack(spacing: 14) {
                            ForEach(SupportResourceItem.resources(for: currentLang)) { item in
                                ResourceLinkRow(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    buttonTitle: item.buttonTitle,
                                    systemImage: item.systemImage,
                                    accent: item.accent
                                ) {
                                    openResource(item.urlString)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )

                    Text(strings.footer)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
        }
        .navigationTitle(strings.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(white: 0.05), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func openResource(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}

private struct SupportInfoCard: View {
    let title: String
    let message: String
    let accent: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.55))
            }

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineSpacing(4)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - App Icon Selection Page / 应用图标选择页面
struct AppIconSelectionView: View {
    @Binding var currentLang: AppLanguage
    let brandColor: Color
    @AppStorage("activeAppIcon") private var selectedIcon: String = "Default"
    @State private var isSwitchingIcon = false
    @State private var iconSwitchError = ""
    @State private var lastSwitchAt = Date.distantPast

    var strings: IconPageStrings {
        IconPageStrings.get(for: currentLang)
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(strings.defaultSection)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 16)

                        HStack {
                            IconOption(name: "Default", iconView: AnyView(LocalAuthLogo()), isSelected: selectedIcon == "Default", isEnabled: !isSwitchingIcon) {
                                changeIcon(to: nil)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text(strings.premiumSection)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 16)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                            IconOption(name: "Neon", iconView: AnyView(NeonLogo()), isSelected: selectedIcon == "Neon", isEnabled: !isSwitchingIcon) {
                                changeIcon(to: "Neon")
                            }

                            IconOption(name: "Dark", iconView: AnyView(DarkLogo()), isSelected: selectedIcon == "Dark", isEnabled: !isSwitchingIcon) {
                                changeIcon(to: "Dark")
                            }

                            IconOption(name: "Retro", iconView: AnyView(RetroLogo()), isSelected: selectedIcon == "Retro", isEnabled: !isSwitchingIcon) {
                                changeIcon(to: "Retro")
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if isSwitchingIcon {
                        ProgressView()
                            .tint(.white)
                    }

                    if !iconSwitchError.isEmpty {
                        Text(iconSwitchError)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(strings.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(white: 0.05), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            selectedIcon = currentSystemIconName
        }
    }

    private func changeIcon(to iconName: String?) {
        if isSwitchingIcon {
            return
        }

        let targetName = iconName ?? "Default"
        if currentSystemIconName == targetName {
            selectedIcon = targetName
            iconSwitchError = ""
            return
        }

        guard UIApplication.shared.supportsAlternateIcons else {
            selectedIcon = currentSystemIconName
            iconSwitchError = strings.notSupported
            return
        }

        isSwitchingIcon = true
        iconSwitchError = ""
        Task { @MainActor in
            let switched = await switchIconWithThrottle(to: iconName)
            selectedIcon = currentSystemIconName
            if !switched {
                iconSwitchError = strings.failed
            }
            isSwitchingIcon = false
        }
    }

    private var currentSystemIconName: String {
        UIApplication.shared.alternateIconName ?? "Default"
    }

    @MainActor
    private func switchIconWithThrottle(to iconName: String?) async -> Bool {
        let passed = Date().timeIntervalSince(lastSwitchAt)
        let minimumInterval: TimeInterval = 2.6
        if passed < minimumInterval {
            let wait = minimumInterval - passed
            let nanos = UInt64(wait * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
        }

        let switched = await switchIcon(to: iconName)
        if switched {
            lastSwitchAt = Date()
        }
        return switched
    }

    @MainActor
    private func switchIcon(to iconName: String?) async -> Bool {
        let current = UIApplication.shared.alternateIconName
        if current == iconName {
            return true
        }

        return await setIconResiliently(iconName, retries: 2)
    }

    @MainActor
    private func setIconResiliently(_ iconName: String?, retries: Int) async -> Bool {
        for attempt in 0...retries {
            if UIApplication.shared.alternateIconName == iconName {
                return true
            }

            do {
                try await setAlternateIconName(iconName)
                if UIApplication.shared.alternateIconName == iconName {
                    return true
                }
                try? await Task.sleep(nanoseconds: 450_000_000)
                if UIApplication.shared.alternateIconName == iconName {
                    return true
                }
            } catch {
                if attempt == retries {
                    print("更换图标失败: \(error.localizedDescription)")
                    return false
                }
            }

            let backoff = UInt64((0.9 + Double(attempt) * 0.6) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: backoff)
        }

        return UIApplication.shared.alternateIconName == iconName
    }

    @MainActor
    private func setAlternateIconName(_ iconName: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
