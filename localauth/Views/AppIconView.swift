import SwiftUI

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let u = canvasSize.width / 1024.0

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * u, y: y * u)
            }

            // 1. Rounded-rectangle background with gradient / 1. 带渐变的圆角矩形背景
            let bgPath = RoundedRectangle(cornerRadius: 226 * u, style: .continuous)
                .path(in: CGRect(origin: .zero, size: canvasSize))
            context.fill(bgPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.039, green: 0.082, blue: 0.149), location: 0),
                    .init(color: Color(red: 0.027, green: 0.165, blue: 0.220), location: 0.5),
                    .init(color: Color(red: 0.024, green: 0.714, blue: 0.831), location: 1.0)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
            ))

            // 2. Outer border / 2. 外边框
            let outerBorder = RoundedRectangle(cornerRadius: 218 * u, style: .continuous)
                .path(in: CGRect(x: 8 * u, y: 8 * u, width: 1008 * u, height: 1008 * u))
            context.stroke(outerBorder, with: .color(.white.opacity(0.2)), lineWidth: 4 * u)

            // 3. Inner border / 3. 内边框
            let innerBorder = RoundedRectangle(cornerRadius: 202 * u, style: .continuous)
                .path(in: CGRect(x: 24 * u, y: 24 * u, width: 976 * u, height: 976 * u))
            context.stroke(innerBorder, with: .color(.white.opacity(0.05)), lineWidth: 2 * u)

            // 4. Ring track background / 4. 圆环轨道背景
            let trackRect = CGRect(x: (512 - 320) * u, y: (512 - 320) * u, width: 640 * u, height: 640 * u)
            let trackPath = Circle().path(in: trackRect)
            context.stroke(trackPath, with: .color(.white.opacity(0.08)), lineWidth: 44 * u)

            // 5. Cyan progress arc with glow / 5. 带辉光的青色进度弧线
            var arcPath = Path()
            let arcCenter = p(512, 512)
            let arcRadius = 320 * u
            let arcDegrees = 1500.0 / 2010.0 * 360.0
            arcPath.addArc(center: arcCenter, radius: arcRadius,
                           startAngle: .degrees(-90),
                           endAngle: .degrees(-90 + arcDegrees),
                           clockwise: false)

            var glowCtx = context
            glowCtx.addFilter(.shadow(color: Color(red: 0, green: 0.941, blue: 1).opacity(0.5), radius: 15 * u))
            glowCtx.stroke(arcPath, with: .color(Color(red: 0, green: 0.941, blue: 1)),
                           style: StrokeStyle(lineWidth: 44 * u, lineCap: .round))

            // 6. Shield with shadow / 6. 带阴影的盾牌
            var shieldPath = Path()
            shieldPath.move(to: p(512, 280))
            shieldPath.addLine(to: p(360, 320))
            shieldPath.addLine(to: p(360, 540))
            shieldPath.addCurve(to: p(512, 760), control1: p(360, 680), control2: p(512, 760))
            shieldPath.addCurve(to: p(664, 540), control1: p(512, 760), control2: p(664, 680))
            shieldPath.addLine(to: p(664, 320))
            shieldPath.closeSubpath()

            var shadowCtx = context
            shadowCtx.addFilter(.shadow(color: .black.opacity(0.35), radius: 16 * u, x: 0, y: 18 * u))
            shadowCtx.fill(shieldPath, with: .color(.white.opacity(0.12)))
            shadowCtx.stroke(shieldPath, with: .color(.white.opacity(0.4)),
                             style: StrokeStyle(lineWidth: 6 * u, lineJoin: .round))

            // 7. Keyhole circle / 7. 锁孔圆形部分
            let keyCircle = Circle().path(in: CGRect(
                x: (512 - 45) * u, y: (470 - 45) * u,
                width: 90 * u, height: 90 * u
            ))
            context.fill(keyCircle, with: .color(.white))

            // 8. Keyhole trapezoid / 8. 锁孔梯形部分
            var trapezoid = Path()
            trapezoid.move(to: p(486, 490))
            trapezoid.addLine(to: p(538, 490))
            trapezoid.addLine(to: p(554, 620))
            trapezoid.addLine(to: p(470, 620))
            trapezoid.closeSubpath()
            context.fill(trapezoid, with: .color(.white))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 226.0 / 1024.0, style: .continuous))
    }
}
