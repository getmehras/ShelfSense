import Foundation
import SwiftData

@Observable
final class StoresViewModel {

    private(set) var itemComparisons: [PriceComparisonViewModel.SavingsOpportunity] = []
    private(set) var totalPotentialSavings: Double = 0

    func update(groceryItems: [GroceryItem]) {
        itemComparisons = PriceComparisonViewModel.topSavingsOpportunities(from: groceryItems, limit: 10)
        totalPotentialSavings = itemComparisons.reduce(0) { $0 + $1.savings }
    }
}
