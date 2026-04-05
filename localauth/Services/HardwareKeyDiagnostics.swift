import Foundation

actor HardwareKeyDiagnosticsCenter {
    static let shared = HardwareKeyDiagnosticsCenter()

    private var operation = ""
    private var entries: [String] = []
    private var counter = 0
    private let maxEntries = 14

    func begin(_ operation: String) {
        self.operation = operation
        self.entries = []
        self.counter = 0
        append("操作: \(operation)")
    }

    func record(_ message: String) {
        append(message)
    }

    func end(success: Bool) {
        append(success ? "结果: 成功" : "结果: 失败")
    }

    func snapshot() -> String? {
        guard !entries.isEmpty else {
            return nil
        }
        return entries.suffix(maxEntries).joined(separator: "\n")
    }

    private func append(_ message: String) {
        counter += 1
        entries.append("\(counter). \(message)")
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}

struct HardwareFIDOUserFacingError: LocalizedError {
    let message: String
    let diagnostics: String?

    var errorDescription: String? {
        guard let diagnostics, !diagnostics.isEmpty else {
            return message
        }
        return "\(message)\n\n诊断信息：\n\(diagnostics)"
    }
}

extension CTAP2Command {
    var diagnosticLabel: String {
        switch self {
        case .makeCredential:
            return "makeCredential"
        case .getAssertion:
            return "getAssertion"
        case .getInfo:
            return "getInfo"
        case .clientPIN:
            return "clientPIN"
        }
    }
}

extension CTAP2TransportError {
    var diagnosticLabel: String {
        switch self {
        case .notAvailable:
            return "notAvailable"
        case .commandNotSupported:
            return "commandNotSupported"
        case .operationFailed:
            return "operationFailed"
        case .timeout:
            return "timeout"
        case .invalidResponse:
            return "invalidResponse"
        case .ctapStatus(let status):
            return String(format: "ctapStatus(0x%02X)", status)
        }
    }
}
