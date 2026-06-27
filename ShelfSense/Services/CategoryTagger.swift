import Foundation

struct CategoryTagger {

    struct Result {
        let category: String     // ItemCategory.rawValue
        let subCategory: String? // nil unless category == ItemCategory.grocery.rawValue
    }

    /// Valid grocery sub-category labels — used in pickers and for AI/manual entry.
    static let grocerySubCategories = [
        "Dairy", "Bakery", "Produce", "Meat", "Pantry", "Beverages", "Snacks"
    ]

    /// Full two-level classification. Top-level category + grocery sub-category when applicable.
    /// Use this everywhere a category is needed — only call `category(for:)` for legacy compat.
    static func classify(_ name: String) -> Result {
        let top = topLevelCategory(for: name)
        let sub = top == ItemCategory.grocery.rawValue ? grocerySubCategory(for: name) : nil
        return Result(category: top, subCategory: sub)
    }

    /// Returns just the top-level `ItemCategory.rawValue`. Legacy convenience — prefer `classify(_:)`.
    static func category(for name: String) -> String {
        topLevelCategory(for: name)
    }

    // MARK: - Private

    private static func topLevelCategory(for name: String) -> String {
        let lower = name.lowercased()

        let rules: [(ItemCategory, [String])] = [
            // Electronics checked first to prevent "battery" matching Household's keyword list
            (.electronics, [
                "phone", "iphone", "samsung", "tablet", "ipad", "laptop", "computer",
                "tv", "television", "monitor", "speaker", "headphone", "earphone", "earbud",
                "charger", "cable", "battery", "camera", "printer", "keyboard", "mouse",
                "remote", "console", "gaming", "usb", "hdmi", "bluetooth", "wifi", "router",
            ]),
            (.clothing, [
                "shirt", "t-shirt", "tshirt", "pants", "jeans", "shorts", "skirt", "dress",
                "jacket", "coat", "sweater", "hoodie", "socks", "underwear", "bra", "shoes",
                "sneakers", "boots", "sandals", "hat", "cap", "gloves", "scarf", "belt",
                "swimsuit", "leggings", "pajamas", "pyjamas",
            ]),
            (.personalCare, [
                "shampoo", "conditioner", "body wash", "deodorant", "antiperspirant",
                "toothpaste", "toothbrush", "mouthwash", "floss", "razor", "shaving",
                "lotion", "moisturizer", "sunscreen", "sunblock", "lip balm", "lipstick",
                "mascara", "foundation", "concealer", "blush", "eyeshadow", "nail polish",
                "perfume", "cologne", "hair gel", "hair spray", "cotton swab", "cotton ball",
                "feminine", "tampon", "pad ", "bandage", "vitamin", "supplement",
            ]),
            (.household, [
                "detergent", "laundry", "fabric softener", "dryer sheet",
                "dish soap", "dishwasher", "cleaner", "disinfectant", "bleach", "windex",
                "sponge", "scrubber", "mop", "broom", "vacuum",
                "toilet paper", "paper towel", "tissue", "napkin",
                "trash bag", "garbage bag", "ziploc", "plastic wrap", "aluminum foil",
                "light bulb", "candle", "air freshener", "febreze",
                "batteries",  // generic household use (remotes, clocks) — "battery" (singular) hits Electronics above
            ]),
            (.grocery, [
                "milk", "cheese", "yogurt", "butter", "cream", "egg",
                "bread", "bagel", "muffin", "croissant", "roll", "bun", "tortilla",
                "pita", "baguette", "cake", "cookie", "brownie",
                "apple", "banana", "orange", "grape", "berry", "lemon", "lime",
                "lettuce", "spinach", "kale", "tomato", "cucumber", "pepper",
                "onion", "garlic", "carrot", "broccoli", "potato", "avocado",
                "mango", "peach", "plum", "celery", "zucchini", "mushroom",
                "chicken", "beef", "pork", "salmon", "tuna", "shrimp",
                "turkey", "lamb", "steak", "sausage", "bacon", "ham", "tilapia",
                "oil", "sauce", "pasta", "rice", "flour", "sugar", "salt",
                "vinegar", "mayo", "ketchup", "mustard", "honey", "jam",
                "peanut butter", "soup", "broth", "cereal", "oat", "granola",
                "bean", "lentil", "canned", "spice", "seasoning",
                "juice", "soda", "cola", "coke", "pepsi", "lemonade",
                "gatorade", "energy drink", "water", "tea", "coffee", "kombucha",
                "almond milk", "oat milk", "sparkling",
                "chip", "cracker", "candy", "chocolate", "ice cream", "frozen",
                "pizza", "waffle", "pretzel", "popcorn",
            ]),
        ]

        for (cat, keywords) in rules {
            if keywords.contains(where: { lower.contains($0) }) {
                return cat.rawValue
            }
        }

        return ItemCategory.other.rawValue
    }

    private static func grocerySubCategory(for name: String) -> String? {
        let lower = name.lowercased()

        let subRules: [(String, [String])] = [
            ("Dairy",     ["milk", "cheese", "yogurt", "butter", "cream", "egg"]),
            ("Bakery",    ["bread", "bagel", "muffin", "croissant", "roll", "bun", "tortilla",
                           "pita", "baguette", "cake", "cookie", "brownie"]),
            ("Produce",   ["apple", "banana", "orange", "grape", "berry", "lemon", "lime",
                           "lettuce", "spinach", "kale", "tomato", "cucumber", "pepper",
                           "onion", "garlic", "carrot", "broccoli", "potato", "avocado",
                           "mango", "peach", "plum", "celery", "zucchini", "mushroom"]),
            ("Meat",      ["chicken", "beef", "pork", "salmon", "tuna", "shrimp",
                           "turkey", "lamb", "steak", "sausage", "bacon", "ham", "tilapia"]),
            ("Pantry",    ["oil", "sauce", "pasta", "rice", "flour", "sugar", "salt",
                           "vinegar", "mayo", "ketchup", "mustard", "honey", "jam",
                           "peanut butter", "soup", "broth", "cereal", "oat", "granola",
                           "bean", "lentil", "canned", "spice", "seasoning"]),
            ("Beverages", ["juice", "soda", "cola", "coke", "pepsi", "dr pepper",
                           "water", "tea", "coffee", "kombucha", "lemonade", "gatorade",
                           "powerade", "energy drink", "monster", "red bull",
                           "almond milk", "oat milk", "sparkling", "carbonated"]),
            ("Snacks",    ["chip", "cracker", "candy", "chocolate", "ice cream", "frozen",
                           "pizza", "waffle", "pretzel", "popcorn"]),
        ]

        for (subCat, keywords) in subRules {
            if keywords.contains(where: { lower.contains($0) }) {
                return subCat
            }
        }

        return nil
    }
}
