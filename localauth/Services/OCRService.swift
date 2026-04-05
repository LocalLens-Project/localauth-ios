import Foundation
import Vision
import UIKit

enum OCRService {
    private static let base32Pattern = try? NSRegularExpression(pattern: "[A-Z2-7]{16,64}", options: [])
    private static let otpauthPattern = try? NSRegularExpression(pattern: "otpauth://[^\\s]+", options: [])

    /// Extracts Base32 secrets and otpauth:// URIs from an image / 从图片中提取 Base32 密钥与 otpauth:// URI
    static func extractSecrets(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let results: [String] = try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            let request = VNRecognizeTextRequest { request, error in
                guard !didResume else { return }
                didResume = true

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var found: [String] = []
                guard let base32Pattern = Self.base32Pattern,
                      let otpauthPattern = Self.otpauthPattern else {
                    continuation.resume(returning: [])
                    return
                }

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let text = candidate.string
                    let range = NSRange(text.startIndex..., in: text)

                    // Match otpauth:// URIs first / 先匹配 otpauth:// URI
                    for match in otpauthPattern.matches(in: text, range: range) {
                        if let r = Range(match.range, in: text) {
                            found.append(String(text[r]))
                        }
                    }

                    // Match cleaned Base32 candidates / 匹配清洗后的 Base32 候选字符串
                    let cleaned = text.uppercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                    let cleanedRange = NSRange(cleaned.startIndex..., in: cleaned)
                    for match in base32Pattern.matches(in: cleaned, range: cleanedRange) {
                        if let r = Range(match.range, in: cleaned) {
                            let candidate = String(cleaned[r])
                            if !found.contains(candidate) {
                                found.append(candidate)
                            }
                        }
                    }
                }

                continuation.resume(returning: found)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard !didResume else { return }
                didResume = true
                continuation.resume(throwing: error)
            }
        }

        return results
    }
}
