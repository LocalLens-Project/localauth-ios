import SwiftUI

struct TokenAppearancePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let confirmTitle: String
    let initialIconName: String
    let initialColorHex: String
    let autoDismissOnConfirm: Bool
    let onCancel: (() -> Void)?
    let onConfirm: (String, String) -> Void

    @State private var selectedIcon: String
    @State private var selectedColorHex: String

    init(
        title: String,
        confirmTitle: String = String(localized: "保存"),
        initialIconName: String,
        initialColorHex: String,
        autoDismissOnConfirm: Bool = true,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping (String, String) -> Void
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.initialIconName = initialIconName
        self.initialColorHex = initialColorHex
        self.autoDismissOnConfirm = autoDismissOnConfirm
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedIcon = State(initialValue: initialIconName)
        _selectedColorHex = State(initialValue: initialColorHex)
    }

    private let iconOptions = [
        "key.fill", "terminal.fill", "envelope.fill", "globe",
        "server.rack", "icloud.fill", "bitcoinsign.circle.fill",
        "creditcard.fill", "building.2.fill", "gamecontroller.fill",
        "cart.fill", "heart.fill", "shield.fill", "lock.fill",
        "person.fill", "star.fill",
    ]

    private let colorOptions: [(name: String, hex: String)] = [
        (String(localized: "蓝"), "007AFF"), (String(localized: "青"), "00D4FF"), (String(localized: "绿"), "34C759"),
        (String(localized: "橙"), "FF9500"), (String(localized: "红"), "FF3B30"), (String(localized: "紫"), "AF52DE"),
        (String(localized: "黄"), "FFD60A"), (String(localized: "灰"), "8E8E93"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "图标"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedIcon == icon ? .cyan : .white.opacity(0.5))
                                    .frame(width: 36, height: 36)
                                    .background(selectedIcon == icon ? Color.cyan.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture { selectedIcon = icon }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "颜色"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.hex) { option in
                                Circle()
                                    .fill(Color(hex: option.hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColorHex == option.hex ? 2 : 0)
                                    )
                                    .onTapGesture { selectedColorHex = option.hex }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "取消")) {
                    if let onCancel {
                        onCancel()
                    } else {
                        dismiss()
                    }
                }
                .foregroundColor(.cyan)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(confirmTitle) {
                    onConfirm(selectedIcon, selectedColorHex)
                    if autoDismissOnConfirm {
                        dismiss()
                    }
                }
                .foregroundColor(.cyan)
            }
        }
    }
}
