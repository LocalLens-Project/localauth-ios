import SwiftUI

struct HardwarePINPromptView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let requiresConfirmation: Bool
    let confirmTitle: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "请输入PIN"), text: $pin)
                        .textContentType(.password)
                        .keyboardType(.numberPad)
                    if requiresConfirmation {
                        SecureField(String(localized: "请再次输入PIN"), text: $confirmPIN)
                            .textContentType(.password)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text(title)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(subtitle)
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "PIN验证"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        submit()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
    }

    private var isValidInput: Bool {
        let normalized = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        if requiresConfirmation {
            return !normalized.isEmpty && !confirmPIN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !normalized.isEmpty
    }

    private func submit() {
        let normalized = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            errorMessage = String(localized: "PIN不能为空。")
            return
        }
        if requiresConfirmation {
            let normalizedConfirm = confirmPIN.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized == normalizedConfirm else {
                errorMessage = String(localized: "两次输入的PIN不一致。")
                return
            }
        }
        errorMessage = nil
        onConfirm(normalized)
        dismiss()
    }
}
