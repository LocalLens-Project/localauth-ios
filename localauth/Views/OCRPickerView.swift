import SwiftUI
import PhotosUI

struct OCRPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSecretsFound: ([String]) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var candidates: [String] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    if candidates.isEmpty && !isProcessing {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .screenshots
                        ) {
                            VStack(spacing: 16) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 48))
                                    .foregroundColor(.cyan)
                                Text(String(localized: "选择包含密钥的截图"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else if isProcessing {
                        ProgressView()
                            .tint(.cyan)
                            .scaleEffect(1.5)
                        Text(String(localized: "正在识别..."))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        List {
                            ForEach(candidates, id: \.self) { candidate in
                                Button {
                                    onSecretsFound([candidate])
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if candidate.hasPrefix("otpauth://") {
                                            Text(String(localized: "OTP 链接"))
                                                .font(.system(size: 12))
                                                .foregroundColor(.cyan)
                                        } else {
                                            Text(String(localized: "Base32 密钥"))
                                                .font(.system(size: 12))
                                                .foregroundColor(.cyan)
                                        }
                                        Text(candidate)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.white.opacity(0.05))
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            .navigationTitle(String(localized: "截图识别"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                isProcessing = true
                errorMessage = nil
                Task {
                    do {
                        guard let data = try await newItem.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else {
                            errorMessage = String(localized: "无法加载图片")
                            isProcessing = false
                            return
                        }
                        candidates = try await OCRService.extractSecrets(from: image)
                        if candidates.isEmpty {
                            errorMessage = String(localized: "未识别到有效密钥")
                        }
                    } catch {
                        errorMessage = String(
                            format: String(localized: "识别失败：%@"),
                            error.localizedDescription
                        )
                    }
                    isProcessing = false
                }
            }
        }
    }
}
