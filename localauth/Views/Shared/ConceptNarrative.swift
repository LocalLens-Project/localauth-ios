import SwiftUI

enum SegmentType {
    case text(String)
    case keyword(String, Double)
}

enum FlowToken: Hashable {
    case text(String, UUID)
    case keyword(String, Double, UUID)
}

enum ConceptNarrative {
    static func tokens() -> [FlowToken] {
        tokenize(segments: segments())
    }

    static func segments() -> [SegmentType] {
        [
            .text(String(localized: "独揽令牌 ")), .keyword(String(localized: "首创"), 0.2), .text(String(localized: " 引入了 ")), .keyword(String(localized: "分级安全"), 0.6),
            .text(String(localized: " 架构，打破了传统验证器在“绝对便利”与“绝对安全”之间非黑即白的困境。我们将硬件密钥能力从单一路径扩展为双通道：对于社交媒体等日常账号，您只需通过 ")),
            .keyword("Face ID", 1.2), .text(String(localized: " 即可顺滑获取动态密码；而对于加密钱包等致命资产，则利用 ")),
            .keyword("YubiKey", 1.8), .text(String(localized: " 与 ")), .keyword("Token2", 2.2),
            .text(String(localized: " 等通用硬件密钥的 ")), .keyword("hmac-secret", 2.6),
            .text(String(localized: " 能力进行硬件级临时解密计算。这种设计不仅突破了物理密钥的容量限制，更在默认保持 ")),
            .keyword(String(localized: "纯本地环境"), 2.8), .text(String(localized: " 的日常体验中，为您打造了一个专属数字保险箱。只有在你主动使用旅行寄存时，才会临时连接网络。"))
        ]
    }

    private static func tokenize(segments: [SegmentType]) -> [FlowToken] {
        var tokens: [FlowToken] = []

        for segment in segments {
            switch segment {
            case .text(let string):
                for char in string {
                    tokens.append(.text(String(char), UUID()))
                }
            case .keyword(let text, let delay):
                tokens.append(.keyword(text, delay, UUID()))
            }
        }

        return tokens
    }
}

struct AnimatedKeyword: View {
    let text: String
    let delay: Double
    let brandColor: Color

    @State private var trimEnd: CGFloat = 0.0
    @State private var opacity: Double = 1.0

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(brandColor)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .trim(from: 0, to: trimEnd)
                    .stroke(brandColor, lineWidth: 1.5)
                    .opacity(opacity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(brandColor.opacity(0.1)))
                    .padding(.vertical, -4)
            )
            .onAppear { startAnimation() }
    }

    private func startAnimation() {
        trimEnd = 0.0
        opacity = 1.0
        withAnimation(.easeInOut(duration: 1.2).delay(delay)) { trimEnd = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(delay + 2.0)) { opacity = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 2.8) { startAnimation() }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(bounds: proposal.replacingUnspecifiedDimensions(), subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(bounds: bounds.size, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY)
            subview.place(at: point, proposal: .unspecified)
        }
    }

    private func computeLayout(bounds: CGSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (CGSize(width: bounds.width, height: currentY + lineHeight), frames)
    }
}
