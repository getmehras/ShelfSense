import Foundation

struct CategoryTagger {
    static func category(for name: String) -> String {
        let lower = name.lowercased()

        let rules: [(String, [String])] = [
            ("Dairy",          ["milk", "cheese", "yogurt", "butter", "cream", "egg"]),
            ("Bakery",         ["bread", "bagel", "muffin", "croissant", "roll", "bun", "tortilla", "pita", "baguette"]),
            ("Produce",        ["apple", "banana", "orange", "grape", "berry", "lemon", "lime",
                                "lettuce", "spinach", "kale", "tomato", "cucumber", "pepper",
                                "onion", "garlic", "carrot", "broccoli", "potato", "avocado",
                                "mango", "peach", "plum", "celery", "zucchini", "mushroom"]),
            ("Meat & Seafood", ["chicken", "beef", "pork", "salmon", "tuna", "shrimp",
                                "turkey", "lamb", "steak", "sausage", "bacon", "ham", "tilapia"]),
            ("Pantry",         ["oil", "sauce", "pasta", "rice", "flour", "sugar", "salt",
                                "vinegar", "mayo", "ketchup", "mustard", "honey", "jam",
                                "peanut butter", "soup", "broth", "cereal", "oat", "granola",
                                "bean", "lentil", "canned", "spice", "seasoning"]),
            ("Beverages",      ["juice", "soda", "water", "tea", "coffee", "kombucha",
                                "almond milk", "oat milk", "sparkling"]),
            ("Snacks & Frozen", ["cookie", "chip", "cracker", "candy", "chocolate",
                                 "ice cream", "frozen", "pizza", "waffle", "pretzel", "popcorn"]),
            ("Household",      ["detergent", "soap", "shampoo", "conditioner", "toothpaste",
                                "cleaner", "tissue", "toilet paper", "paper towel", "dish", "sponge"]),
        ]

        for (category, keywords) in rules {
            if keywords.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return "General"
    }
}
