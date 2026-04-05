import Foundation
import CommonCrypto

enum TOTPGenerator {
    /// Generates an RFC 6238 TOTP code / 生成 RFC 6238 TOTP 验证码
    static func generate(
        secret: Data,
        time: Date = Date(),
        period: Int = 30,
        digits: Int = 6,
        algorithm: TokenAlgorithm = .sha1
    ) -> String {
        let normalizedPeriod = max(period, 1)
        let normalizedDigits = min(max(digits, 1), 10)
        let counter = UInt64(floor(time.timeIntervalSince1970 / Double(normalizedPeriod)))
        var bigEndianCounter = counter.bigEndian
        let counterData = Data(bytes: &bigEndianCounter, count: 8)
        let hmacBytes = hmac(secret: secret, message: counterData, algorithm: algorithm)

        // Apply RFC 4226 section 5.4 dynamic truncation / 执行 RFC 4226 第 5.4 节的动态截断
        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
        let truncated = (UInt64(hmacBytes[offset]) & 0x7F) << 24
            | UInt64(hmacBytes[offset + 1]) << 16
            | UInt64(hmacBytes[offset + 2]) << 8
            | UInt64(hmacBytes[offset + 3])

        let modulus = UInt64(pow(10.0, Double(normalizedDigits)))
        let mod = truncated % modulus
        return String(format: "%0\(normalizedDigits)llu", mod)
    }

    /// Returns the remaining seconds in the current period / 返回当前周期剩余秒数
    static func remainingSeconds(time: Date = Date(), period: Int = 30) -> Int {
        let normalizedPeriod = max(period, 1)
        let elapsed = Int(time.timeIntervalSince1970) % normalizedPeriod
        return normalizedPeriod - elapsed
    }

    /// Returns the current period progress from 0.0 to 1.0 for ring animation / 返回当前周期 0.0 到 1.0 的进度，用于圆环动画
    static func progress(time: Date = Date(), period: Int = 30) -> CGFloat {
        let normalizedPeriod = max(period, 1)
        let remainder = time.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(normalizedPeriod))
        return CGFloat(1.0 - remainder / Double(normalizedPeriod))
    }

    private static func hmac(secret: Data, message: Data, algorithm: TokenAlgorithm) -> [UInt8] {
        let algorithmValue: CCHmacAlgorithm
        let digestLength: Int

        switch algorithm {
        case .sha1:
            algorithmValue = CCHmacAlgorithm(kCCHmacAlgSHA1)
            digestLength = Int(CC_SHA1_DIGEST_LENGTH)
        case .sha256:
            algorithmValue = CCHmacAlgorithm(kCCHmacAlgSHA256)
            digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        case .sha512:
            algorithmValue = CCHmacAlgorithm(kCCHmacAlgSHA512)
            digestLength = Int(CC_SHA512_DIGEST_LENGTH)
        case .md5:
            algorithmValue = CCHmacAlgorithm(kCCHmacAlgMD5)
            digestLength = Int(CC_MD5_DIGEST_LENGTH)
        }

        var output = [UInt8](repeating: 0, count: digestLength)
        secret.withUnsafeBytes { secretBytes in
            message.withUnsafeBytes { messageBytes in
                CCHmac(
                    algorithmValue,
                    secretBytes.baseAddress,
                    secret.count,
                    messageBytes.baseAddress,
                    message.count,
                    &output
                )
            }
        }
        return output
    }
}
