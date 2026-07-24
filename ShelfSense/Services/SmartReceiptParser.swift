import Foundation

// MARK: - Parser Hint

struct ParserHint {
    enum PriceColumn { case left, right }
    let hasSKU: Bool
    let priceColumn: PriceColumn
}

// MARK: - SmartReceiptParser

final class SmartReceiptParser {

    // Words that indicate a line is NOT a product
    static let skipKeywords: [String] = [
        "TOTAL", "SUBTOTAL", "SUB-TOTAL", "SUB TOTAL", "SUB TITAL",
        "TAX", "SALES TAX", "HST", "GST", "PST",
        "CHANGE", "CASH", "CREDIT", "DEBIT",
        "BALANCE", "AMOUNT DUE", "AMOUNT PAID", "PAID AMOUNT",
        "SAVINGS", "YOU SAVED", "DISCOUNT",
        "COUPON", "PROMO", "PROMOTION",
        "POINTS", "REWARDS", "FUEL POINTS",
        "LOYALTY", "LOYAL",
        "DEPOSIT", "FEE", "SURCHARGE",
        "THANK", "WELCOME", "RECEIPT",
        "MEMBER", "CARD NUMBER", "CARDS USED",
        "SALE", "SPECIAL PRICE",
        "ITEM COUNT", "ITEMS SOLD", "ITEM/QUANTITY", "ITEM QTY",
        "APPROVED", "AUTHORIZATION", "TERMINAL",
        "TRANSACTION", "REF#", "AUTH",
        "VOID", "RETURN POLICY",
        "STORE #", "STORE NUMBER",
        "PHONE", "FAX", "HOURS",
        "PAYMENT SUMMARY", "PAYMENT",
        "TIP AMOUNT", "TIP AROUNT", "TIP",
        "CASHIER", "REGISTER",
        "WALK-IN", "CUSTOMER NAME",
        "www.", "http",
        // Payment card brands and card-number references
        "VISA", "MASTERCARD", "MASTER CARD", "AMEX", "AMERICAN EXPRESS",
        "DISCOVER", "INTERAC", "CARD ENDING", "LAST 4", "LAST FOUR",
        // Payment summary lines that look like items but aren't
        "AMOUNT",
        // Header words that appear at the top of receipts
        "WHOLESALE", "CHECKOUT", "SELF-SERVICE", "AID:", "APP#", "SEQ#", "RESP:",
    ]

    // Store-specific parsing hints
    static let storeHints: [String: ParserHint] = [
        "WALMART":      ParserHint(hasSKU: true,  priceColumn: .right),
        "WAL-MART":     ParserHint(hasSKU: true,  priceColumn: .right),
        "TARGET":       ParserHint(hasSKU: true,  priceColumn: .right),
        "KROGER":       ParserHint(hasSKU: false, priceColumn: .right),
        "HEB":          ParserHint(hasSKU: false, priceColumn: .right),
        "H-E-B":        ParserHint(hasSKU: false, priceColumn: .right),
        "WHOLE FOODS":  ParserHint(hasSKU: false, priceColumn: .right),
        "COSTCO":       ParserHint(hasSKU: true,  priceColumn: .right),
        "TRADER JOE":   ParserHint(hasSKU: true,  priceColumn: .right),
        "ALDI":         ParserHint(hasSKU: false, priceColumn: .right),
        "PUBLIX":       ParserHint(hasSKU: false, priceColumn: .right),
        "SAFEWAY":      ParserHint(hasSKU: false, priceColumn: .right),
        "SPROUTS":      ParserHint(hasSKU: false, priceColumn: .right),
        "MEIJER":       ParserHint(hasSKU: true,  priceColumn: .right),
        "WEGMANS":      ParserHint(hasSKU: false, priceColumn: .right),
        "FRESH MARKET": ParserHint(hasSKU: false, priceColumn: .right),
        "SMART":        ParserHint(hasSKU: false, priceColumn: .right),
        "FOOD LION":    ParserHint(hasSKU: false, priceColumn: .right),
    ]

    // MARK: - Main entry point

    static func parse(lines: [String], storeName: String = "") -> [ParsedReceiptItem] {
        let hint = detectHint(for: storeName)
        var items: [ParsedReceiptItem] = []
        var previousLine = ""

        for line in lines {
            let trimmed = normalizeDecimalSeparators(line.trimmingCharacters(in: .whitespaces))
            let upper = trimmed.uppercased()

            guard !shouldSkipLine(upper) else {
                previousLine = trimmed
                continue
            }

            // Try tabular format first: "Name  qty  unit_price  total"
            let tabular = extractTabular(from: trimmed)
            let price: Double
            let qty: Double

            if let tab = tabular {
                price = tab.unitPrice
                qty   = tab.qty
            } else {
                guard let p = extractPrice(from: trimmed) else {
                    // No price on this line — keep as fallback name for next line
                    previousLine = trimmed
                    continue
                }
                price = p
                qty   = extractQuantity(from: trimmed)
            }

            guard price > 0.01, price < 2000 else {
                previousLine = trimmed
                continue
            }

            let rawName = extractName(from: trimmed, fallback: previousLine, hint: hint)

            guard let cleanName = cleanItemName(rawName, hint: hint), cleanName.count > 3 else {
                previousLine = trimmed
                continue
            }

            let perUnit = price / max(qty, 1)
            let unitInfo = UnitPriceCalculator.parse(name: cleanName, price: perUnit)
            items.append(ParsedReceiptItem(
                name: cleanName,
                price: price,
                quantity: qty,
                unitPrice: unitInfo?.unitPrice,
                unitType: unitInfo?.baseUnit
            ))
            previousLine = trimmed
        }

        // If few items found, the receipt may use a two-column layout (e.g. Costco) where
        // Vision OCR returns all item names first, then all prices as standalone lines.
        // Try pairing them positionally.
        if items.count < 3 {
            let paired = tryColumnPairing(lines: lines, hint: hint)
            if paired.count > items.count {
                return removeDuplicates(paired)
            }
        }

        return removeDuplicates(items)
    }

    // MARK: - Two-column layout pairing
    //
    // Handles receipts (Costco, some Walmart/Target) where Vision OCR reads the left
    // column (item names) entirely before the right column (prices). Collects name-only
    // lines and price-only lines separately, then pairs them in order.
    // Street-type words that only appear in addresses, never in product names.
    private static let streetSuffixes: [String] = [
        " BLVD", " BOULEVARD", " STREET", " AVE ", " AVENUE",
        " ROAD", " LANE", " DRIVE", " PKWY", " PARKWAY",
        " COURT", " PLACE", " HIGHWAY", " HWY",
        // Trailing suffix at end of line (no space after needed)
        "BLVD.", "PKWY.", "AVE.", "ST.", "RD.", "DR.", "LN.",
    ]

    // Returns true when a line looks like a receipt header (store info, address, phone)
    // rather than a purchasable item. All checks are format-based — no store names hardcoded.
    static func isHeaderLine(_ line: String) -> Bool {
        let upper = line.uppercased().trimmingCharacters(in: .whitespaces)

        // Street address: contains a street-type suffix word
        if streetSuffixes.contains(where: { upper.contains($0) }) { return true }

        // City / State / Zip: e.g. "TX 78660" or "Pflugerville, TX 78660"
        if upper.range(of: #"\b[A-Z]{2}\s+\d{5}\b"#, options: .regularExpression) != nil { return true }

        // Phone number: (512) 555-1234 or 512-555-1234 or 512.555.1234
        if upper.range(of: #"\(?\d{3}\)?[\s.\-]\d{3}[\s.\-]\d{4}"#, options: .regularExpression) != nil { return true }

        // "City," — city name followed by a comma (precedes state/zip on the next line)
        if line.trimmingCharacters(in: .whitespaces).hasSuffix(",") { return true }

        // Store/receipt number standalone: "#1234" with no other meaningful text
        if upper.range(of: #"^#\d{3,}"#, options: .regularExpression) != nil { return true }

        return false
    }

    static func tryColumnPairing(lines: [String], hint: ParserHint?) -> [ParsedReceiptItem] {
        var nameLines: [String] = []
        var priceLines: [String] = []
        // Once the right-column price block starts, any following text is the
        // payment footer (AID:, Seq#, card info) — stop collecting names.
        var seenFirstPriceLine = false

        for line in lines {
            let trimmed = normalizeDecimalSeparators(line.trimmingCharacters(in: .whitespaces))
            guard !trimmed.isEmpty else { continue }
            let upper = trimmed.uppercased()

            // Price-only check FIRST — shouldSkipLine rejects number-only lines, so we
            // capture standalone prices (e.g. "11.99", "49.99 A") before that filter runs.
            let isPriceOnly = trimmed.range(
                of: #"^\$?(\d{1,4}\.\d{2})\s*[A-Z]?\s*$"#,
                options: .regularExpression
            ) != nil
            if isPriceOnly && !trimmed.contains("-") {
                if let price = extractPrice(from: trimmed), price > 0.01, price < 2000 {
                    priceLines.append(trimmed)
                    seenFirstPriceLine = true
                }
                continue
            }

            // Skip keyword lines (TOTAL, TAX, APPROVED, VISA, WHOLESALE, etc.)
            if shouldSkipLine(upper) { continue }

            // Once prices have started, remaining text is payment footer — stop here.
            if seenFirstPriceLine { continue }

            // Filter generic header content: addresses, phone numbers, city/zip lines.
            // These checks are format-based and work across all store formats.
            if isHeaderLine(trimmed) { continue }

            // Name-only: no extractable price, has ≥ 3 letters.
            // cleanItemName will further strip SKU codes, weights, and tax codes.
            if extractPrice(from: trimmed) == nil,
               trimmed.filter(\.isLetter).count >= 3 {
                nameLines.append(trimmed)
            }
        }

        guard !nameLines.isEmpty, !priceLines.isEmpty else { return [] }

        // Pair positionally. Extra price entries at the end (subtotal/tax/total values
        // that follow item prices) are beyond pairCount and naturally ignored.
        let pairCount = min(nameLines.count, priceLines.count)
        var items: [ParsedReceiptItem] = []

        for i in 0..<pairCount {
            let nameLine  = nameLines[i]
            let priceLine = priceLines[i]
            guard let price = extractPrice(from: priceLine), price > 0.01, price < 2000 else { continue }
            let rawName = extractName(from: nameLine, fallback: "", hint: hint)
            guard let cleanName = cleanItemName(rawName, hint: hint), cleanName.count > 3 else { continue }
            let unitInfo = UnitPriceCalculator.parse(name: cleanName, price: price)
            items.append(ParsedReceiptItem(
                name: cleanName,
                price: price,
                quantity: 1,
                unitPrice: unitInfo?.unitPrice,
                unitType: unitInfo?.baseUnit
            ))
        }

        return items
    }

    // MARK: - Store hint detection

    static func detectHint(for storeName: String) -> ParserHint? {
        let upper = storeName.uppercased()
        for (key, hint) in storeHints where upper.contains(key) {
            return hint
        }
        return nil
    }

    // MARK: - Skip detection

    static func shouldSkipLine(_ upperLine: String) -> Bool {
        // Weight descriptor lines: "@2.870 lb", "@1.400 1"
        if upperLine.hasPrefix("@") { return true }
        // Lone unit-suffix artifacts OCR'd as their own line
        let trimmed = upperLine.trimmingCharacters(in: .whitespaces)
        if ["B", "LB", "LBS", "KG", "OZ", "1B", "ICK"].contains(trimmed) { return true }
        // Lines that are only digits and punctuation (stray barcode / totals column fragments)
        let letters = upperLine.filter(\.isLetter)
        if letters.isEmpty && upperLine.filter(\.isNumber).count > 0 { return true }
        // Masked card number: ****1234, XXXX 1234, XX-1234, etc.
        if upperLine.range(of: #"[*X]{2,}[\s\-]*\d{3,4}"#, options: .regularExpression) != nil { return true }
        return skipKeywords.contains(where: { upperLine.contains($0) })
    }

    // MARK: - Decimal normalization

    // OCR on thermal receipts often produces "7,49" instead of "7.49"
    static func normalizeDecimalSeparators(_ line: String) -> String {
        line.replacingOccurrences(of: #"(\d),(\d{2})(\b|$|\s)"#,
                                  with: "$1.$2$3",
                                  options: .regularExpression)
    }

    // MARK: - Price extraction

    // Finds a price at or near the end of a line: $3.99, 3.99, 3.99 F, 3.99 TX
    // Skips lines with a negative sign (returns/voids)
    static func extractPrice(from line: String) -> Double? {
        let normalized = normalizeDecimalSeparators(line)
        guard !normalized.contains("-") else { return nil }
        let pattern = #"\$?(\d{1,4}\.\d{2})\s*[A-Z]{0,3}\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              let range = Range(match.range(at: 1), in: normalized) else { return nil }
        return Double(normalized[range])
    }

    // MARK: - Tabular row extraction

    // Detects "Item Name  qty  unit_price  total" format used by many grocers.
    // Returns (qty, unitPrice) when the math checks out (qty × unitPrice ≈ total).
    // Uses unitPrice rather than total so per-item comparisons are meaningful.
    static func extractTabular(from line: String) -> (qty: Double, unitPrice: Double)? {
        let normalized = normalizeDecimalSeparators(line)
        // Pattern: ... (integer qty) (unit price) (line total) at end
        let pattern = #"(\d+)\s+(\d{1,4}\.\d{2})\s+(\d{1,4}\.\d{2})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized,
                                           range: NSRange(normalized.startIndex..., in: normalized)),
              match.numberOfRanges >= 4,
              let qtyRange  = Range(match.range(at: 1), in: normalized),
              let unitRange = Range(match.range(at: 2), in: normalized),
              let totRange  = Range(match.range(at: 3), in: normalized),
              let qty       = Double(normalized[qtyRange]),
              let unitPrice = Double(normalized[unitRange]),
              let total     = Double(normalized[totRange]),
              qty >= 1, qty <= 99, unitPrice > 0.01 else { return nil }

        // Verify: qty × unitPrice ≈ total within 15% (covers weight-based rounding)
        let expected = qty * unitPrice
        guard total > 0, abs(expected - total) / total < 0.15 else { return nil }
        return (qty, unitPrice)
    }

    // MARK: - Name extraction

    static func extractName(from line: String, fallback: String, hint: ParserHint?) -> String {
        // Try stripping the tabular suffix first: qty  unit_price  total
        let tabularPattern = #"\s+\d+\s+\d{1,4}\.\d{2}\s+\d{1,4}\.\d{2}\s*$"#
        // Fall back to stripping just a single trailing price + optional tax code
        let pricePattern   = #"\s*\$?\d{1,4}\.\d{2}\s*[A-Z]{0,3}\s*$"#

        for pattern in [tabularPattern, pricePattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = line as NSString
            let stripped = regex.stringByReplacingMatches(
                in: line,
                range: NSRange(location: 0, length: ns.length),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)

            if stripped.count >= 3 {
                return stripped
            }
        }
        return fallback.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Quantity extraction

    static func extractQuantity(from line: String) -> Double {
        // "2 @ $1.99" or "2 @ 1.99"
        if let m = line.range(of: #"^(\d+)\s*@"#, options: .regularExpression) {
            let numStr = line[m].components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            if let qty = Double(numStr), qty > 1 { return qty }
        }
        // "2 x ITEM" or "2 X ITEM"
        if let m = line.range(of: #"^(\d)\s*[xX]\s"#, options: .regularExpression) {
            let numStr = line[m].components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            if let qty = Double(numStr), qty > 1 { return qty }
        }
        return 1
    }

    // MARK: - Name cleaning

    static func cleanItemName(_ raw: String, hint: ParserHint? = nil) -> String? {
        var s = raw

        // Remove leading quantity patterns: "2 @ $1.99 " or "3 x "
        s = s.replacingOccurrences(of: #"^\d+\s*[@xX]\s*\$?\d*\.?\d*\s*"#,
                                   with: "", options: .regularExpression)

        // Remove SKU / barcode numbers
        let skuDigits = hint?.hasSKU == true ? 4 : 5
        let skuPattern = "\\b\\d{\(skuDigits),}\\b"
        s = s.replacingOccurrences(of: skuPattern, with: "", options: .regularExpression)

        // Remove weight info: "1.23 LB", "16 OZ", "0.5 KG"
        s = s.replacingOccurrences(
            of: #"\d+\.?\d*\s*(LB|LBS|KG|OZ|FL OZ|FL\.OZ|EA|CT|PCS?)\b"#,
            with: "", options: [.regularExpression, .caseInsensitive])

        // Remove trailing single/double-letter tax codes: " F", " N", " TX", " NT"
        s = s.replacingOccurrences(of: #"\s+[A-Z]{1,2}\s*$"#,
                                   with: "", options: .regularExpression)

        // Remove stray punctuation that receipts leave behind
        s = s.replacingOccurrences(of: "#", with: " ")
        s = s.replacingOccurrences(of: "*", with: " ")
        s = s.replacingOccurrences(of: "@", with: " ")

        // Collapse runs of whitespace
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespaces)

        // Title-case
        s = s.capitalized

        // Reject empties, too-short strings, all-digit strings, lone codes
        guard s.count > 3 else { return nil }
        guard s.first?.isLetter == true else { return nil }
        let letterCount = s.filter(\.isLetter).count
        guard letterCount >= 3 else { return nil }

        return s
    }

    // MARK: - Deduplication

    static func removeDuplicates(_ items: [ParsedReceiptItem]) -> [ParsedReceiptItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = "\(item.name.lowercased())-\(item.price)"
            return seen.insert(key).inserted
        }
    }
}
