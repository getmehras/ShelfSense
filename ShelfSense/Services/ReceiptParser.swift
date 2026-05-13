import Vision
import UIKit

struct ReceiptParser {

    nonisolated func parse(images: [UIImage]) async -> ParsedReceipt {
        var allLines: [String] = []
        for image in images {
            let lines = await recognizeText(in: image)
            allLines.append(contentsOf: lines)
        }
        return parseLines(allLines)
    }

    // MARK: - OCR

    private nonisolated func recognizeText(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Parsing

    private nonisolated func parseLines(_ lines: [String]) -> ParsedReceipt {
        let storeName = extractStoreName(from: lines)
        var items: [ParsedReceiptItem] = []
        var detectedTotal: Double?

        for line in lines {
            let lower = line.lowercased()

            if lower.contains("total") && !lower.contains("subtotal") {
                detectedTotal = extractLastPrice(from: line) ?? detectedTotal
                continue
            }
            if shouldSkipLine(lower) { continue }
            if let item = parseItem(from: line) {
                items.append(item)
            }
        }

        return ParsedReceipt(storeName: storeName, items: items, detectedTotal: detectedTotal)
    }

    private nonisolated func extractStoreName(from lines: [String]) -> String {
        for line in lines.prefix(6) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else { continue }
            guard trimmed.first?.isLetter == true else { continue }
            guard trimmed.firstMatch(of: /\d{5}/) == nil else { continue } // skip zip codes
            return trimmed
        }
        return "Unknown Store"
    }

    private nonisolated func shouldSkipLine(_ lower: String) -> Bool {
        let skipWords = [
            "subtotal", "sub-total", "sub total", "sales tax", "cash",
            "change", "balance", "debit", "credit", "visa", "mastercard",
            "approved", "terminal", "ref#", "auth", "account", "card",
            "payment", "thank you", "transaction", "member", "loyalty",
            "points", "discount", "coupon", "promo", "savings", "item count"
        ]
        return skipWords.contains { lower.contains($0) }
    }

    private nonisolated func extractLastPrice(from line: String) -> Double? {
        line.matches(of: /\$?(\d{1,4}\.\d{2})/).last.flatMap { Double($0.output.1) }
    }

    private nonisolated func parseItem(from line: String) -> ParsedReceiptItem? {
        // Price must appear at the end of the line, optionally followed by a tax code
        guard let priceMatch = line.firstMatch(of: /\$?(\d{1,3}\.\d{2})\s*[A-Z]?\s*$/) else {
            return nil
        }
        guard let price = Double(priceMatch.output.1), price > 0.01 else { return nil }

        // Everything before the price is the item description
        let nameCandidate = String(line[line.startIndex..<priceMatch.range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard nameCandidate.count >= 2 else { return nil }

        // Detect quantity patterns like "2 @ 1.99 ITEM" or "3 x ITEM"
        var quantity = 1.0
        var cleanName = nameCandidate

        if let m = nameCandidate.firstMatch(of: /^(\d+)\s*@\s*\$?(\d+\.\d{2})\s+(.+)$/) {
            quantity = Double(m.output.1) ?? 1
            cleanName = String(m.output.3)
        } else if let m = nameCandidate.firstMatch(of: /^(\d)\s+([A-Za-z].{2,})$/) {
            quantity = Double(m.output.1) ?? 1
            cleanName = String(m.output.2)
        }

        // Skip lines where the "name" is just digits or very short
        guard cleanName.first?.isLetter == true || cleanName.contains(" ") else { return nil }

        let finalName = cleanName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        guard finalName.count >= 2 else { return nil }

        // Per-package price (price ÷ quantity) is what we normalize per oz/fl oz/ea
        let perPackagePrice = price / max(quantity, 1)
        let unitInfo = UnitPriceCalculator.parse(name: finalName, price: perPackagePrice)

        return ParsedReceiptItem(
            name: finalName,
            price: price,
            quantity: quantity,
            unitPrice: unitInfo?.unitPrice,
            unitType: unitInfo?.baseUnit
        )
    }
}
