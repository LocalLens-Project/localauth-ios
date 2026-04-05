import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    AppIconView(size: 100)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    Text(String(localized: "独揽令牌"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("v\(appVersion)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 4)

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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 28)

                    VStack(spacing: 0) {
                        aboutRow(title: String(localized: "开发团队"), value: OpenSourceProjectInfo.contributorsLabel)
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "旅行寄存"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text(String(localized: "这是一个低频紧急功能。默认令牌体验仍以本地为主；只有在你主动创建或下载旅行寄存时，应用才会联网，且上传内容全程端到端加密。"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.72))
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    if let projectStoryURL = URL(string: OpenSourceProjectInfo.projectStoryURLString) {
                        Link(destination: projectStoryURL) {
                            HStack(spacing: 4) {
                                Text(String(localized: "创作历程"))
                                    .fontWeight(.medium)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.cyan)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.cyan.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 20)
                    }

                    Text("© 2026 \(OpenSourceProjectInfo.contributorsLabel)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.top, 36)
                        .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(String(localized: "关于我们"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(white: 0.05), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
