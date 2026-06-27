import Foundation
import SwiftData

@Observable
final class StoresViewModel {

    struct ItemComparison: Identifiable {
        let id = UUID()
        let itemName: String
        let cheapestStore: String
        let cheapestPrice: Double
        let mostExpensiveStore: String
        let mostExpensivePrice: Double
        // Set when both stores have unit prices in the same base unit
        let unitComparisonText: String?
        var savings: Double { max(0, mostExpensivePrice - cheapestPrice) }
    }

    private(set) var itemComparisons: [ItemComparison] = []
    private(set) var totalPotentialSavings: Double = 0

    func update(groceryItems: [GroceryItem]) {
        // Reuse PriceComparisonViewModel's fuzzy grouping so items like "A2 Milk" (HEB)
        // and "A2 Milk 2%" (Randalls) — stored as separate GroceryItems — are still compared.
        let opportunities = PriceComparisonViewModel.topSavingsOpportunities(from: groceryItems, limit: 10)
        itemComparisons = opportunities.map { opp in
            ItemComparison(
                itemName: opp.displayName,
                cheapestStore: opp.cheapestStoreName,
                cheapestPrice: opp.cheapestPrice,
                mostExpensiveStore: opp.mostExpensiveStoreName,
                mostExpensivePrice: opp.mostExpensivePrice,
                unitComparisonText: nil
            )
        }
        totalPotentialSavings = itemComparisons.reduce(0) { $0 + $1.savings }
    }
}
