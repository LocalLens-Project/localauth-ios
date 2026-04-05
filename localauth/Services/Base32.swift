import Foundation

enum Base32 {
    enum DecodingError: Error {
        case invalidCharacter
    }

    private static let alphabet: [Character: UInt8] = {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var map: [Character: UInt8] = [:]
        for (i, c) in chars.enumerated() {
            map[c] = UInt8(i)
        }
        return map
    }()

    /// Decodes RFC 4648 Base32 input / 解码 RFC 4648 Base32 输入
    static func decode(_ input: String) throws -> Data {
        // Normalize the input by removing spaces, hyphens, and padding, then uppercasing it / 通过移除空格、连字符和填充并统一转大写来规范化输入
        let cleaned = input
            .uppercased()
            .filter { $0 != " " && $0 != "-" && $0 != "=" }

        guard !cleaned.isEmpty else { return Data() }

        var buffer: UInt64 = 0
        var bitsLeft = 0
        var output = Data()
        output.reserveCapacity(cleaned.count * 5 / 8)

        for char in cleaned {
            guard let value = alphabet[char] else {
                throw DecodingError.invalidCharacter
            }
            buffer = (buffer << 5) | UInt64(value)
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                output.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }
        return output
    }

    /// Encodes data as RFC 4648 Base32 / 按 RFC 4648 Base32 编码数据
    static func encode(_ data: Data) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var result = ""
        var buffer: UInt64 = 0
        var bitsLeft = 0

        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                result.append(chars[Int((buffer >> bitsLeft) & 0x1F)])
            }
        }
        if bitsLeft > 0 {
            result.append(chars[Int((buffer << (5 - bitsLeft)) & 0x1F)])
        }
        return result
    }
}
