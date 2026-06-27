import Vision
import UIKit

// Returned by parse(images:) so callers can distinguish a clean receipt from a bad scan
// without needing to inspect a partially-populated ParsedReceipt.
enum ScanParseResult {
    case success(ParsedReceipt)
    case validationFailed(ReceiptScanValidator.FailureReason)
}

struct ReceiptParser {

    // MARK: - Public API

    nonisolated func parse(images: [UIImage]) async -> ScanParseResult {
        ScanMetrics.increment(ScanMetrics.keyAttempts)

        var allLines: [String] = []
        var allConfidences: [Float] = []

        for image in images {
            let (lines, confidence) = await recognizeText(in: image)
            allLines.append(contentsOf: lines)
            allConfidences.append(confidence)
        }

        let avgConfidence = allConfidences.isEmpty
            ? Float(1.0)
            : allConfidences.reduce(0, +) / Float(allConfidences.count)
        let rawText = allLines.joined(separator: "\n")

        // Validate OCR quality before spending an API call
        let validation = ReceiptScanValidator.validate(
            ocrText: rawText,
            lines: allLines,
            averageConfidence: avgConfidence
        )
        if case .failed(let reason) = validation {
            ScanMetrics.increment(ScanMetrics.keyFailures)
            return .validationFailed(reason)
        }

        let ocrStoreName = extractStoreName(from: allLines)
        let detectedTotal = extractTotal(from: allLines)
        let result = await parseReceiptItems(rawText: rawText, ocrStoreName: ocrStoreName)

        return .success(ParsedReceipt(
            storeName: result.storeName,
            storeAddress: result.storeAddress,
            date: result.purchaseDate ?? .now,
            items: result.items,
            detectedTotal: result.receiptTotal ?? detectedTotal, // prefer backend over OCR
            receiptSubtotal: result.receiptSubtotal,
            salesTax: result.salesTax,
            usedAI: result.usedAI
        ))
    }

    // Debug mode skips validation so developers can inspect any OCR output.
    nonisolated func parseWithDebug(images: [UIImage]) async -> (ParsedReceipt, ParseDebugInfo) {
        var allLines: [String] = []
        for image in images {
            let (lines, _) = await recognizeText(in: image)
            allLines.append(contentsOf: lines)
        }
        let storeName = extractStoreName(from: allLines)
        let detectedTotal = extractTotal(from: allLines)
        let collector = DebugCollector()
        let items = SmartReceiptParser.parse(lines: allLines, storeName: storeName,
                                             collector: collector)
        let receipt = ParsedReceipt(storeName: storeName, items: items,
                                    detectedTotal: detectedTotal)
        let debugInfo = ParseDebugInfo(
            rawLines: allLines,
            storeName: storeName,
            detectedTotal: detectedTotal,
            acceptedItems: collector.accepted.map {
                ParseDebugInfo.AcceptedItem(originalLine: $0.line,
                                            cleanedName: $0.name,
                                            price: $0.price)
            },
            rejectedLines: collector.rejected.map {
                ParseDebugInfo.RejectedLine(text: $0.text, reason: $0.reason)
            }
        )
        return (receipt, debugInfo)
    }

    // MARK: - Smart routing

    private nonisolated func parseReceiptItems(
        rawText: String,
        ocrStoreName: String
    ) async -> (items: [ParsedReceiptItem], usedAI: Bool, storeName: String,
                storeAddress: String?, purchaseDate: Date?,
                receiptSubtotal: Double?, salesTax: Double?, receiptTotal: Double?) {

        let limiter = ScanLimitManager.shared

        if limiter.hasAIScansRemaining {
            ScanMetrics.increment(ScanMetrics.keyApiCalls)
            do {
                let result = try await BackendReceiptParser.parse(
                    rawOCRText: redactSensitiveLines(from: rawText),
                    storeName: ocrStoreName)

                if !result.items.isEmpty {
                    await MainActor.run { limiter.useAIScan() }
                    let finalStoreName = result.storeName.isEmpty ? ocrStoreName : result.storeName
                    return (result.items, true, finalStoreName,
                            result.storeAddress, result.purchaseDate,
                            result.receiptSubtotal, result.salesTax, result.receiptTotal)
                }
            } catch BackendReceiptParser.ParserError.networkError {
                // Offline — fall through to local parser
            } catch {
                // Any backend error — fall through to local parser
            }
        }

        // Local fallback: offline, scans exhausted, or backend returned empty
        let lines = rawText.components(separatedBy: .newlines)
        let items = SmartReceiptParser.parse(lines: lines, storeName: ocrStoreName)
        return (items, false, ocrStoreName, nil, nil, nil, nil, nil)
    }

    // MARK: - Pre-send scrubbing

    private nonisolated func redactSensitiveLines(from text: String) -> String {
        let cardKeywords = [
            "VISA", "MASTERCARD", "MASTER CARD", "AMEX", "AMERICAN EXPRESS",
            "DISCOVER", "INTERAC", "CREDIT CARD", "DEBIT CARD",
            "CARD ENDING", "CARD NUMBER", "CARDS USED", "LAST 4", "LAST FOUR",
            "APPROVED", "AUTHORIZATION", "ACCOUNT NUMBER",
        ]
        return text
            .components(separatedBy: .newlines)
            .filter { line in
                let upper = line.uppercased()
                if cardKeywords.contains(where: { upper.contains($0) }) { return false }
                if upper.range(of: #"[*X]{2,}[\s\-]*\d{3,4}"#, options: .regularExpression) != nil { return false }
                if upper.range(of: #"^\s*\d{4}\s*$"#, options: .regularExpression) != nil { return false }
                return true
            }
            .joined(separator: "\n")
    }

    // MARK: - Vision OCR

    private nonisolated func recognizeText(in image: UIImage) async -> (lines: [String], avgConfidence: Float) {
        guard let cgImage = image.cgImage else { return ([], 1.0) }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let confidences = observations.compactMap { $0.topCandidates(1).first?.confidence }
                let avg = confidences.isEmpty
                    ? Float(1.0)
                    : confidences.reduce(0, +) / Float(confidences.count)
                continuation.resume(returning: (lines, avg))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: ([], 1.0))
            }
        }
    }

    // MARK: - Helpers

    private nonisolated func extractStoreName(from lines: [String]) -> String {
        for line in lines.prefix(10) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else { continue }
            guard trimmed.first?.isLetter == true else { continue }
            guard trimmed.firstMatch(of: /\d{5}/) == nil else { continue }
            return StoreNameNormalizer.normalize(trimmed)
        }
        return "Unknown Store"
    }

    private nonisolated func extractTotal(from lines: [String]) -> Double? {
        for line in lines.reversed() {
            let lower = line.lowercased()
            guard lower.contains("total"), !lower.contains("subtotal") else { continue }
            if let match = line.matches(of: /\$?(\d{1,4}\.\d{2})/).last,
               let price = Double(match.output.1) {
                return price
            }
        }
        return nil
    }
}
