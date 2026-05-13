import Foundation

enum UnitPriceCalculator {

    struct UnitInfo {
        let amount: Double
        let rawUnit: String
        let baseUnit: String    // "oz", "fl oz", "ea"
        let unitPrice: Double   // price per base unit

        var displayLabel: String {
            unitPrice < 0.10
                ? String(format: "$%.3f/%@", unitPrice, baseUnit)
                : String(format: "$%.2f/%@", unitPrice, baseUnit)
        }
    }

    // Returns nil when no unit pattern is found in the item name.
    nonisolated static func parse(name: String, price: Double) -> UnitInfo? {
        guard price > 0 else { return nil }
        let s = name.lowercased()
        return parseWeight(s, price: price)
            ?? parseVolume(s, price: price)
            ?? parseCount(s, price: price)
    }

    // MARK: - Weight → normalised to oz

    private nonisolated static func parseWeight(_ s: String, price: Double) -> UnitInfo? {
        let rules: [(String, String, Double)] = [
            (#"(\d+(?:\.\d+)?)\s*kg\b"#,   "kg", 35.274),
            (#"(\d+(?:\.\d+)?)\s*lbs?\b"#, "lb", 16.0),
            (#"(\d+(?:\.\d+)?)\s*g\b"#,    "g",  0.035274),
            (#"(\d+(?:\.\d+)?)\s*oz\b"#,   "oz", 1.0),
        ]
        for (pattern, unit, multiplier) in rules {
            guard let amount = firstCapture(pattern, in: s).flatMap(Double.init) else { continue }
            let totalOz = amount * multiplier
            guard totalOz > 0 else { continue }
            return UnitInfo(amount: amount, rawUnit: unit, baseUnit: "oz", unitPrice: price / totalOz)
        }
        return nil
    }

    // MARK: - Volume → normalised to fl oz

    private nonisolated static func parseVolume(_ s: String, price: Double) -> UnitInfo? {
        let rules: [(String, String, Double)] = [
            (#"(\d+(?:\.\d+)?)\s*fl\.?\s*oz\b"#,       "fl oz", 1.0),
            (#"(\d+(?:\.\d+)?)\s*(?:liter|litre|l)\b"#, "l",    33.814),
            (#"(\d+(?:\.\d+)?)\s*ml\b"#,                "ml",   0.033814),
        ]
        for (pattern, unit, multiplier) in rules {
            guard let amount = firstCapture(pattern, in: s).flatMap(Double.init) else { continue }
            let totalFlOz = amount * multiplier
            guard totalFlOz > 0 else { continue }
            return UnitInfo(amount: amount, rawUnit: unit, baseUnit: "fl oz", unitPrice: price / totalFlOz)
        }
        return nil
    }

    // MARK: - Count → price per unit

    private nonisolated static func parseCount(_ s: String, price: Double) -> UnitInfo? {
        let rules: [(String, String)] = [
            (#"(\d+)\s*(?:ct|count)\b"#, "ct"),
            (#"(\d+)\s*(?:pk|pack)\b"#,  "pk"),
            (#"(\d+)\s*pcs?\b"#,         "pc"),
            (#"(\d+)\s*ea\b"#,           "ea"),
        ]
        for (pattern, unit) in rules {
            guard let amount = firstCapture(pattern, in: s).flatMap(Double.init), amount > 1 else { continue }
            return UnitInfo(amount: amount, rawUnit: unit, baseUnit: "ea", unitPrice: price / amount)
        }
        return nil
    }

    // MARK: - Regex helper

    private nonisolated static func firstCapture(_ pattern: String, in s: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: s)
        else { return nil }
        return String(s[range])
    }
}
