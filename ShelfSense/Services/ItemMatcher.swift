import Foundation

struct ItemMatcher {
    // Bigram Jaccard threshold — tuned for grocery item names
    static let similarityThreshold: Double = 0.72

    private static let abbreviations: [String: String] = [
        "org":     "organic",
        "orig":    "original",
        "nat":     "natural",
        "ff":      "fat free",
        "lf":      "low fat",
        "nf":      "nonfat",
        "choc":    "chocolate",
        "van":     "vanilla",
        "chk":     "chicken",
        "chkn":    "chicken",
        "grnd":    "ground",
        "frzn":    "frozen",
        "frsh":    "fresh",
        "unswt":   "unsweetened",
        "swt":     "sweetened",
        "grk":     "greek",
        "multigr": "multigrain",
        "ww":      "whole wheat",
        "unsltd":  "unsalted",
        "sltd":    "salted",
        "lg":      "large",
        "lrg":     "large",
        "sm":      "small",
        "med":     "medium",
        "xl":      "extra large",
        "xlg":     "extra large",
    ]

    private static let stopWords: Set<String> = ["the", "a", "an", "and", "with", "of", "in", "for"]

    // Canonical form: split on non-alphanumeric, expand abbreviations, drop stop words, sort.
    // "Org. Milk" and "Organic Milk" both produce "milk organic".
    static func normalize(_ name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .flatMap { token -> [String] in
                let expanded = abbreviations[token] ?? token
                // Re-split multi-word expansions like "fat free"
                return expanded.components(separatedBy: " ").filter { !$0.isEmpty }
            }
            .filter { !stopWords.contains($0) }
            .sorted()
            .joined(separator: " ")
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        let normA = normalize(a)
        let normB = normalize(b)
        if normA == normB { return 1.0 }
        let bA = bigrams(normA)
        let bB = bigrams(normB)
        let intersectionCount = bA.intersection(bB).count
        let unionCount = bA.union(bB).count
        guard unionCount > 0 else { return 0 }
        return Double(intersectionCount) / Double(unionCount)
    }

    // Returns the best-matching item above the similarity threshold, or nil.
    static func findMatch(for name: String, in items: [GroceryItem]) -> GroceryItem? {
        items
            .map { (item: $0, score: similarity(name, $0.name)) }
            .filter { $0.score >= similarityThreshold }
            .max(by: { $0.score < $1.score })?
            .item
    }

    private static func bigrams(_ s: String) -> Set<String> {
        let chars = Array(s)
        guard chars.count >= 2 else { return [s] }
        return Set((0..<chars.count - 1).map { String([chars[$0], chars[$0 + 1]]) })
    }
}
