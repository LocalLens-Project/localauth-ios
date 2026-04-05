import SwiftUI

struct OnboardingOpenSourceAnnouncementPage: View {
    var onContinue: () -> Void

    @Environment(\.openURL) private var openURL

    @State private var showLine1 = false
    @State private var showStrikePhrase = false
    @State private var drawStrike = false
    @State private var showLine2 = false
    @State private var showHighlightPhrase = false
    @State private var drawUnderline = false
    @State private var showMainTitle = false
    @State private var showBody = false
    @State private var showWebsiteButton = false
    @State private var isContinueEnabled = false
    @State private var didStartAnimations = false

    private let themeCyan = Color.cyan
    private let accentRed = Color(red: 1.0, green: 0.36, blue: 0.36)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 20)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(themeCyan)
                        .padding(.bottom, 6)

                    VStack(alignment: .leading, spacing: 12) {
                        if showLine1 {
                            Text(String(localized: "真正的安全，从来不需要"))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity)
                        }

                        if showStrikePhrase {
                            Text(String(localized: "黑盒里的闭门造车"))
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                                .overlay(alignment: .center) {
                                    Rectangle()
                                        .fill(accentRed)
                                        .frame(height: 3)
                                        .scaleEffect(x: drawStrike ? 1 : 0, anchor: .leading)
                                        .animation(.easeInOut(duration: 0.38), value: drawStrike)
                                }
                                .transition(.opacity)
                        }

                        if showLine2 {
                            Text(String(localized: "而是经得起审视的"))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity)
                        }

                        if showHighlightPhrase {
                            Text(String(localized: "绝对透明"))
                                .font(.system(size: 32, weight: .black))
                                .foregroundStyle(themeCyan)
                                .fixedSize(horizontal: false, vertical: true)
                                .overlay(alignment: .bottomLeading) {
                                    Rectangle()
                                        .fill(themeCyan)
                                        .frame(height: 3)
                                        .offset(y: 7)
                                        .scaleEffect(x: drawUnderline ? 1 : 0, anchor: .leading)
                                        .animation(.easeOut(duration: 0.4), value: drawUnderline)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    if showMainTitle {
                        Text(String(localized: "独揽令牌已开源到 GitHub。"))
                            .font(.system(size: 33, weight: .black))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if showBody {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(String(localized: "代码公开之后，你可以更清楚地审视本地令牌、旅行寄存与硬件密钥相关实现。"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(String(localized: "我们相信，安全工具应该允许用户验证它，而不只是相信它。"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if showWebsiteButton {
                        Button {
                            guard let url = URL(string: OpenSourceProjectInfo.repositoryURLString) else { return }
                            openURL(url)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                Text(String(localized: "查看开源仓库"))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(themeCyan)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(themeCyan.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(themeCyan.opacity(0.65), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 30)
                .padding(.top, 34)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 0) {
                Button(action: onContinue) {
                    Text(String(localized: "继续"))
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isContinueEnabled ? themeCyan : Color.white.opacity(0.16))
                        .foregroundStyle(isContinueEnabled ? Color.black : Color.white.opacity(0.42))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: isContinueEnabled ? themeCyan.opacity(0.38) : .clear, radius: 12, y: 5)
                }
                .disabled(!isContinueEnabled)
                .animation(.easeInOut(duration: 0.28), value: isContinueEnabled)
            }
            .padding(.horizontal, 30)
            .padding(.top, 14)
            .padding(.bottom, 20)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.92),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .task {
            guard !didStartAnimations else { return }
            didStartAnimations = true
            triggerAnimations()
        }
    }

    private func triggerAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.25)) {
                showLine1 = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.25)) {
                showStrikePhrase = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            drawStrike = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.easeIn(duration: 0.25)) {
                showLine2 = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                showHighlightPhrase = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) {
            drawUnderline = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                showMainTitle = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.55) {
            withAnimation(.easeInOut(duration: 0.28)) {
                showBody = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                showWebsiteButton = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isContinueEnabled = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingOpenSourceAnnouncementPage {}
    }
    .preferredColorScheme(.dark)
}
