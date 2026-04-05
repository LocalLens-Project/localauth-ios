import Foundation

struct ParsedToken {
    let issuer: String
    let account: String
    let secretBase32: String
    let digits: Int
    let period: Int
    let algorithm: TokenAlgorithm
}

enum MigrationParser {
    enum ParseError: Error {
        case invalidURL
        case missingSecret
        case invalidMigrationData
        case unsupportedType
        case unsupportedAlgorithm
        case invalidDigits
        case invalidPeriod
    }

    // MARK: - Standard otpauth://totp/ URI / 标准 otpauth://totp/ URI

    static func parseOTPAuthURI(_ string: String) throws -> ParsedToken {
        guard let url = URL(string: string),
              url.scheme == "otpauth",
              url.host == "totp" else {
            throw ParseError.invalidURL
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        guard let secret = queryItems.first(where: { $0.name == "secret" })?.value, !secret.isEmpty else {
            throw ParseError.missingSecret
        }

        let issuerFromQuery = queryItems.first(where: { $0.name == "issuer" })?.value
        let label = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        let labelDecoded = label.removingPercentEncoding ?? label

        // Labels may be formatted as "Issuer:Account" or just "Account" / 标签格式可能是 "Issuer:Account" 或仅 "Account"
        let (labelIssuer, account): (String?, String)
        if let colonRange = labelDecoded.range(of: ":") {
            labelIssuer = String(labelDecoded[labelDecoded.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            account = String(labelDecoded[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            labelIssuer = nil
            account = labelDecoded
        }

        let issuer = issuerFromQuery ?? labelIssuer ?? ""
        let digits = try parseDigits(from: queryItems.first(where: { $0.name == "digits" })?.value)
        let period = try parsePeriod(from: queryItems.first(where: { $0.name == "period" })?.value)
        let algorithm = try parseAlgorithm(from: queryItems.first(where: { $0.name == "algorithm" })?.value)

        return ParsedToken(
            issuer: issuer,
            account: account,
            secretBase32: secret.uppercased(),
            digits: digits,
            period: period,
            algorithm: algorithm
        )
    }

    // MARK: - otpauth-migration://offline?data= (Google Authenticator export) / otpauth-migration://offline?data=（Google Authenticator 迁移）

    static func parseGoogleMigration(_ string: String) throws -> [ParsedToken] {
        guard let url = URL(string: string),
              url.scheme == "otpauth-migration",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataParam = components.queryItems?.first(where: { $0.name == "data" })?.value,
              let rawData = Data(base64Encoded: dataParam) else {
            throw ParseError.invalidMigrationData
        }

        return try decodeGooglePayload(rawData)
    }

    /// Detects the URI type automatically and parses it / 自动检测 URI 类型并解析
    static func parse(_ string: String) throws -> [ParsedToken] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("otpauth-migration://") {
            return try parseGoogleMigration(trimmed)
        } else if trimmed.hasPrefix("otpauth://") {
            return [try parseOTPAuthURI(trimmed)]
        }
        throw ParseError.invalidURL
    }

    // MARK: - Minimal Protobuf Decoder / 最小 Protobuf 解码器

    private static func decodeGooglePayload(_ data: Data) throws -> [ParsedToken] {
        var tokens: [ParsedToken] = []
        var offset = 0

        // Outer message: field 1 stores repeated OtpParameters entries as length-delimited values / 外层消息中，field 1 以 length-delimited 形式存放 repeated OtpParameters
        while offset < data.count {
            let (fieldNumber, wireType, newOffset) = try readTag(data: data, offset: offset)
            offset = newOffset

            if fieldNumber == 1 && wireType == 2 {
                let (innerData, nextOffset) = try readLengthDelimited(data: data, offset: offset)
                offset = nextOffset
                if let token = try? decodeOtpParameters(innerData) {
                    tokens.append(token)
                }
            } else {
                offset = try skipField(data: data, offset: offset, wireType: wireType)
            }
        }
        return tokens
    }

    private static func decodeOtpParameters(_ data: Data) throws -> ParsedToken {
        var offset = 0
        var secret = Data()
        var name = ""
        var issuer = ""
        var algorithmValue: UInt64 = 0
        var digitsValue: UInt64 = 0
        var otpType: UInt64 = 0

        while offset < data.count {
            let (fieldNumber, wireType, newOffset) = try readTag(data: data, offset: offset)
            offset = newOffset

            switch (fieldNumber, wireType) {
            case (1, 2): // secret (bytes) / 密钥（字节）
                let (d, next) = try readLengthDelimited(data: data, offset: offset)
                secret = d
                offset = next
            case (2, 2): // name (string) / 名称（字符串）
                let (d, next) = try readLengthDelimited(data: data, offset: offset)
                name = String(data: d, encoding: .utf8) ?? ""
                offset = next
            case (3, 2): // issuer (string) / 签发方（字符串）
                let (d, next) = try readLengthDelimited(data: data, offset: offset)
                issuer = String(data: d, encoding: .utf8) ?? ""
                offset = next
            case (4, 0): // algorithm (enum) / 算法（枚举）
                let (val, next) = try readVarint(data: data, offset: offset)
                algorithmValue = val
                offset = next
            case (5, 0): // digits (enum) / 位数（枚举）
                let (val, next) = try readVarint(data: data, offset: offset)
                digitsValue = val
                offset = next
            case (_, 0): // varint fields such as algorithm, digits, and type / varint 字段，例如 algorithm、digits、type
                let (val, next) = try readVarint(data: data, offset: offset)
                if fieldNumber == 6 { otpType = val }
                offset = next
            default:
                offset = try skipField(data: data, offset: offset, wireType: wireType)
            }
        }

        // type=2 represents TOTP / type=2 表示 TOTP
        guard !secret.isEmpty else { throw ParseError.missingSecret }
        if otpType != 0 && otpType != 2 { throw ParseError.unsupportedType }

        let account: String
        if let colonRange = name.range(of: ":") {
            account = String(name[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if issuer.isEmpty {
                issuer = String(name[name.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        } else {
            account = name
        }

        return ParsedToken(
            issuer: issuer,
            account: account,
            secretBase32: Base32.encode(secret),
            digits: try mapGoogleDigits(digitsValue),
            period: 30,
            algorithm: try mapGoogleAlgorithm(algorithmValue)
        )
    }

    // MARK: - Protobuf Primitives / Protobuf 原语

    private static func readVarint(data: Data, offset: Int) throws -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift = 0
        var pos = offset
        while pos < data.count {
            let byte = data[pos]
            result |= UInt64(byte & 0x7F) << shift
            pos += 1
            if byte & 0x80 == 0 { return (result, pos) }
            shift += 7
            if shift > 63 { break }
        }
        throw ParseError.invalidMigrationData
    }

    private static func readTag(data: Data, offset: Int) throws -> (fieldNumber: Int, wireType: Int, newOffset: Int) {
        let (value, newOffset) = try readVarint(data: data, offset: offset)
        return (Int(value >> 3), Int(value & 0x07), newOffset)
    }

    private static func readLengthDelimited(data: Data, offset: Int) throws -> (Data, Int) {
        let (length, newOffset) = try readVarint(data: data, offset: offset)
        let end = newOffset + Int(length)
        guard end <= data.count else { throw ParseError.invalidMigrationData }
        return (data[newOffset..<end], end)
    }

    private static func skipField(data: Data, offset: Int, wireType: Int) throws -> Int {
        switch wireType {
        case 0: // varint / 可变整数
            let (_, next) = try readVarint(data: data, offset: offset)
            return next
        case 1: // 64-bit / 64 位
            let end = offset + 8
            guard end <= data.count else { throw ParseError.invalidMigrationData }
            return end
        case 2: // length-delimited / 长度限定
            let (_, next) = try readLengthDelimited(data: data, offset: offset)
            return next
        case 5: // 32-bit / 32 位
            let end = offset + 4
            guard end <= data.count else { throw ParseError.invalidMigrationData }
            return end
        default:
            throw ParseError.invalidMigrationData
        }
    }

    private static func parseDigits(from rawValue: String?) throws -> Int {
        guard let rawValue, !rawValue.isEmpty else { return 6 }
        guard let digits = Int(rawValue), digits > 0, digits <= 10 else {
            throw ParseError.invalidDigits
        }
        return digits
    }

    private static func parsePeriod(from rawValue: String?) throws -> Int {
        guard let rawValue, !rawValue.isEmpty else { return 30 }
        guard let period = Int(rawValue), period > 0 else {
            throw ParseError.invalidPeriod
        }
        return period
    }

    private static func parseAlgorithm(from rawValue: String?) throws -> TokenAlgorithm {
        guard let rawValue, !rawValue.isEmpty else { return .sha1 }
        guard let algorithm = TokenAlgorithm.parse(rawValue) else {
            throw ParseError.unsupportedAlgorithm
        }
        return algorithm
    }

    private static func mapGoogleAlgorithm(_ rawValue: UInt64) throws -> TokenAlgorithm {
        switch rawValue {
        case 0, 1:
            return .sha1
        case 2:
            return .sha256
        case 3:
            return .sha512
        case 4:
            return .md5
        default:
            throw ParseError.unsupportedAlgorithm
        }
    }

    private static func mapGoogleDigits(_ rawValue: UInt64) throws -> Int {
        switch rawValue {
        case 0, 1:
            return 6
        case 2:
            return 8
        default:
            throw ParseError.invalidDigits
        }
    }
}

extension MigrationParser.ParseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "无法识别该 OTP 链接。")
        case .missingSecret:
            return String(localized: "链接中缺少可用的密钥。")
        case .invalidMigrationData:
            return String(localized: "迁移数据格式无效。")
        case .unsupportedType:
            return String(localized: "当前仅支持 TOTP 类型的迁移数据。")
        case .unsupportedAlgorithm:
            return String(localized: "该令牌使用了当前不支持的算法。")
        case .invalidDigits:
            return String(localized: "令牌的验证码位数参数无效。")
        case .invalidPeriod:
            return String(localized: "令牌的周期参数无效。")
        }
    }
}
