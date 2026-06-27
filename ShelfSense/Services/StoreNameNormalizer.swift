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
}
