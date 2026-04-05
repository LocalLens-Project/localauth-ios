import SwiftUI

struct AddTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var onScan: () -> Void
    var onImage: () -> Void
    var onManual: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.white.opacity(0.15))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
            
            Text(String(localized: "添加新令牌"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                actionButton(
                    title: String(localized: "扫描二维码"),
                    icon: "qrcode.viewfinder",
                    iconColor: .cyan,
                    action: onScan
                )
                
                actionButton(
                    title: String(localized: "从截图识别"),
                    icon: "photo.on.rectangle.angled",
                    iconColor: .cyan,
                    action: onImage
                )
                
                actionButton(
                    title: String(localized: "手动输入"),
                    icon: "keyboard",
                    iconColor: .cyan,
                    action: onManual
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding(.top, 8)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea())
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }
    
    private func actionButton(title: String, icon: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                action()
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
    }
    .sheet(isPresented: .constant(true)) {
        AddTokenSheet(onScan: {}, onImage: {}, onManual: {})
    }
}
