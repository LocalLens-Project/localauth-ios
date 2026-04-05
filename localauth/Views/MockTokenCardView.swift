import SwiftUI

// MARK: - Demo Phases / 演示阶段

enum DemoPhase: CaseIterable {
    case locked
    case unlocking
    case unlocked
    case tapping
    case copied
}

// MARK: - Mock Token Card for Demo / 演示用模拟令牌卡片

struct MockTokenCardView: View {
    var issuer: String = "GitHub"
    var account: String = "user@example.com"
    var code: String = "492 104"
    var iconName: String = "globe"
    var accentColor: Color = .cyan
    var progress: CGFloat = 0.7
    var animatesCycle: Bool = false

    @State private var phase: DemoPhase = .locked
    @State private var scale: CGFloat = 1.0
    @State private var appeared = false

    private var isUnlocked: Bool {
        phase != .locked && phase != .unlocking
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left side: icon and countdown ring / 左侧：图标与倒计时圆环
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0.0, to: isUnlocked ? progress : 0)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Image(systemName: isUnlocked ? iconName : "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isUnlocked ? accentColor : .gray)
            }

            // Center: text content / 中间：文本信息
            VStack(alignment: .leading, spacing: 6) {
                Text(issuer)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(account)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Right side: status display / 右侧：状态展示
            ZStack {
                switch phase {
                case .locked, .unlocking:
                    HStack(spacing: 4) {
                        Image(systemName: "faceid")
                        Text(String(localized: "解锁"))
                            .tracking(1)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundColor(.cyan)

                case .unlocked, .tapping, .copied:
                    Text(phase == .copied ? String(localized: "已复制") : code)
                        .font(.system(size: phase == .copied ? 16 : 26, weight: .bold, design: .monospaced))
                        .foregroundColor(phase == .copied ? .green : .white)
                        .tracking(phase == .copied ? 4 : 2)
                        .frame(width: 130, alignment: .trailing)
                        .contentTransition(.numericText())
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
        .onAppear {
            if animatesCycle {
                startCycle()
            }
        }
    }

    // MARK: - Auto Loop Animation / 自动循环动画

    private func startCycle() {
        // Keep the locked state on screen for 1.5 seconds / 锁定态停留 1.5 秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Transition into unlocking / 过渡到解锁中
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .unlocking
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Transition into unlocked / 过渡到已解锁
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .unlocked
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Simulate a tap gesture / 模拟点击动作
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        phase = .tapping
                        scale = 0.95
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            scale = 1.0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Transition into copied feedback / 过渡到已复制反馈
                        withAnimation(.easeInOut(duration: 0.2)) {
                            phase = .copied
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            // Return to the locked state and loop again / 回到锁定态并重新循环
                            withAnimation(.easeInOut(duration: 0.3)) {
                                phase = .locked
                                scale = 1.0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                startCycle()
                            }
                        }
                    }
                }
            }
        }
    }
}
