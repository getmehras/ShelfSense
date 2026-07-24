import Foundation

struct ReceiptScanValidator {

    enum ValidationResult {
        case valid
        case failed(reason: FailureReason)
    }

    enum FailureReason: Equatable {
        case tooShort
        case noText
        case noPricesFound
        case tooFewLines
        case lowConfidence
        case notAReceipt
        case receiptCutOff

        var userMessage: String {
            switch self {
            case .tooShort:
                return "The scan looks incomplete. Try capturing the full receipt from top to bottom."
            case .noText:
                return "No text detected. Make sure the receipt is flat and well lit."
            case .noPricesFound:
                return "No prices detected. Make sure the receipt is in focus and fully captured."
            case .tooFewLines:
                return "Too little text detected. Try scanning again with the full receipt in frame."
            case .lowConfidence:
                return "The scan quality is too low. Try better lighting or hold the phone steadier."
            case .notAReceipt:
                return "This doesn't look like a grocery receipt. Please scan a store receipt."
            case .receiptCutOff:
                return "The receipt appears cut off. Make sure the entire receipt is visible in the frame."
            }
        }

        var retryButtonText: String {
            switch self {
            case .lowConfidence:       return "Try Better Lighting"
            case .receiptCutOff,
                 .tooShort:            return "Capture Full Receipt"
            default:                   return "Scan Again"
            }
        }

        var canProceedWithBasicScan: Bool {
            self == .lowConfidence
        }
    }

    // MARK: - Main Validation

    static func validate(
        ocrText: String,
        lines: [String],
        averageConfidence: Float
    ) -> ValidationResult {

        let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check 1: Empty text
        if trimmed.isEmpty {
            return .failed(reason: .noText)
        }

        // Check 2: Minimum text length — real receipt has at least 100 characters
        if trimmed.count < 100 {
            return .failed(reason: .tooShort)
        }

        // Check 3: Minimum non-empty line count (header + items + total = 8+)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if nonEmptyLines.count < 8 {
            return .failed(reason: .tooFewLines)
        }

        // Check 4: At least 2 price patterns (\d+\.\d{2})
        let priceMatches = try? NSRegularExpression(pattern: #"\d+\.\d{2}"#)
            .matches(in: ocrText, range: NSRange(ocrText.startIndex..., in: ocrText))
        if (priceMatches?.count ?? 0) < 2 {
            return .failed(reason: .noPricesFound)
        }

        // Check 5: Receipt cut-off — missing total keyword on a short scan
        let lower = ocrText.lowercased()
        let hasTotalLine = ["total", "subtotal", "sub total", "amount", "balance", "due"]
            .contains { lower.contains($0) }
        if !hasTotalLine && ocrText.count < 500 {
            return .failed(reason: .receiptCutOff)
        }

        // Check 6: Confidence threshold (below 0.4 = too blurry to parse reliably)
        if averageConfidence < 0.4 {
            return .failed(reason: .lowConfidence)
        }

        // Check 7: Basic receipt indicators
        let hasReceiptIndicator = ["$", "tax", "total", "item", "price", "qty",
                                   "quantity", "receipt", "sale", "purchase"]
            .contains { lower.contains($0) }
        if !hasReceiptIndicator {
            return .failed(reason: .notAReceipt)
        }

        return .valid
    }

    // MARK: - Quick Price Check

    static func hasSufficientPrices(_ text: String) -> Bool {
        let matches = try? NSRegularExpression(pattern: #"\d+\.\d{2}"#)
            .matches(in: text, range: NSRange(text.startIndex..., in: text))
        return (matches?.count ?? 0) >= 3
    }

    // Stub — confidence is computed in ReceiptParser where VNRecognizedTextObservation is available
    static func averageConfidence(from observations: [Any]) -> Float { 1.0 }
}
