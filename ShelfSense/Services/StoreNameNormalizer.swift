import Foundation

struct StoreNameNormalizer {

    static func normalize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return trimmed }

        // Remove store numbers like #123, #1322
        let withoutNumber = trimmed
            .replacingOccurrences(of: #"\s*#\d+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let uppercased = withoutNumber.uppercased()

        // Ordered so more-specific patterns are checked before their prefixes
        let normalizations: [(pattern: String, result: String)] = [
            // HEB variants (check before bare "HEB")
            ("H-E-B",           "HEB"),
            ("H.E.B",           "HEB"),
            ("HEB PLUS",        "HEB"),
            ("HEB GROCERY",     "HEB"),
            ("HEB FOOD",        "HEB"),
            ("HEB",             "HEB"),

            // Walmart variants
            ("WALMART SUPERCENTER",     "Walmart"),
            ("WALMART NEIGHBORHOOD",    "Walmart"),
            ("WAL-MART",                "Walmart"),
            ("WALMART",                 "Walmart"),

            // Target
            ("TARGET",          "Target"),

            // Costco variants (check longer first)
            ("COSTCO WHOLESALE", "Costco"),
            ("COSTCO",           "Costco"),

            // Kroger
            ("KROGER",          "Kroger"),

            // Whole Foods (check longer first)
            ("WHOLE FOODS MARKET", "Whole Foods"),
            ("WHOLE FOODS",        "Whole Foods"),

            // Trader Joe's
            ("TRADER JOE'S",    "Trader Joes"),
            ("TRADER JOES",     "Trader Joes"),

            // Aldi
            ("ALDI",            "Aldi"),

            // Randalls
            ("RANDALL'S",       "Randalls"),
            ("RANDALLS",        "Randalls"),

            // Man Pasand variants
            ("MANPASSAND",      "Man Pasand"),
            ("MAN PASSAND",     "Man Pasand"),
            ("MAN PASAND",      "Man Pasand"),
        ]

        for (pattern, result) in normalizations where uppercased.contains(pattern) {
            return result
        }

        // No known store matched — title-case the cleaned name
        return withoutNumber.capitalized
    }

    /// Normalizes a street address for comparison only — not for display.
    /// Expands common abbreviations so "123 Main St" and "123 Main Street" compare equal.
    static func normalizeAddress(_ address: String) -> String {
        let cleaned = address
            .lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")

        let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let expanded = words.map { word -> String in
            switch word {
            case "st":   return "street"
            case "ave":  return "avenue"
            case "blvd": return "boulevard"
            case "dr":   return "drive"
            case "rd":   return "road"
            case "ln":   return "lane"
            case "ct":   return "court"
            case "pl":   return "place"
            case "pkwy": return "parkway"
            case "hwy":  return "highway"
            case "ste":  return "suite"
            default:     return word
            }
        }
        return expanded.joined(separator: " ")
    }
}
