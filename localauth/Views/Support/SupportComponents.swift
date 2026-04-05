import SwiftUI

// MARK: - Core Components / 基础组件

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - List Row Components / 列表行组件

struct ResourceLinkRow: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let systemImage: String
    let accent: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.2))
                        .frame(width: 54, height: 54)
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accent)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                }
                
                Spacer(minLength: 10)
                
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(accent.opacity(0.25)))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct IconOption: View {
    let name: String
    let iconView: AnyView
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    // Background container / 背景容器
                    iconView
                        .frame(width: 72, height: 72)
                        .shadow(color: isSelected ? .blue.opacity(0.5) : .black.opacity(0.3), radius: 8, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                        )
                }
                
                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.7))
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Icon Drawing / 图标绘制

struct LocalAuthLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color(red: 10/255, green: 21/255, blue: 38/255),
                    Color(red: 7/255, green: 42/255, blue: 56/255),
                    Color(red: 6/255, green: 182/255, blue: 212/255)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .padding(1)
            
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                .padding(10)
            
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(red: 0/255, green: 240/255, blue: 255/255), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(10)
                .shadow(color: Color(red: 0/255, green: 240/255, blue: 255/255).opacity(0.5), radius: 5)
            
            Image(systemName: "shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundColor(.white.opacity(0.12))
                .overlay(
                    Image(systemName: "shield")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white.opacity(0.4))
                )
                .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
            
            Image(systemName: "lock.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12, height: 12)
                .foregroundColor(.white)
                .offset(y: 2)
                .shadow(radius: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct NeonLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color(red: 15/255, green: 5/255, blue: 24/255),
                    Color(red: 46/255, green: 16/255, blue: 101/255),
                    Color(red: 124/255, green: 58/255, blue: 237/255)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .padding(1)
            
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 3)
                .padding(10)
            
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(red: 216/255, green: 180/255, blue: 254/255), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(10)
                .shadow(color: Color(red: 216/255, green: 180/255, blue: 254/255).opacity(0.8), radius: 5)
            
            Image(systemName: "shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundColor(.white.opacity(0.15))
                .overlay(
                    Image(systemName: "shield")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white.opacity(0.5))
                )
                .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
            
            Image(systemName: "bolt.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
                .shadow(radius: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct DarkLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color(red: 0/255, green: 0/255, blue: 0/255),
                    Color(red: 24/255, green: 24/255, blue: 27/255),
                    Color(red: 39/255, green: 39/255, blue: 42/255)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.6), radius: 5, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(white: 0.32), lineWidth: 1))
            
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(white: 0.32).opacity(0.3), lineWidth: 0.5)
                .padding(1)
            
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 3)
                .padding(10)
            
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(red: 228/255, green: 228/255, blue: 231/255), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(10)
                .shadow(color: Color.white.opacity(0.3), radius: 5)
            
            Image(systemName: "shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundColor(.white.opacity(0.1))
                .overlay(
                    Image(systemName: "shield")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white.opacity(0.3))
                )
                .shadow(color: .black.opacity(0.6), radius: 5, y: 2)
            
            Image(systemName: "checkmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
                .shadow(radius: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct RetroLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color(red: 69/255, green: 26/255, blue: 3/255),
                    Color(red: 154/255, green: 52/255, blue: 18/255),
                    Color(red: 234/255, green: 88/255, blue: 12/255)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .padding(1)
            
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                .padding(10)
            
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color(red: 251/255, green: 191/255, blue: 36/255), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(10)
                .shadow(color: Color(red: 251/255, green: 191/255, blue: 36/255).opacity(0.5), radius: 5)
            
            Image(systemName: "shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundColor(.white.opacity(0.12))
                .overlay(
                    Image(systemName: "shield")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white.opacity(0.4))
                )
                .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
            
            Image(systemName: "lock.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12, height: 12)
                .foregroundColor(.white)
                .shadow(radius: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
