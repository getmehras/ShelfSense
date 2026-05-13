import Foundation
import SwiftData

@Observable
final class StoresViewModel {

    struct ItemComparison: Identifiable {
        let id = UUID()
        let itemName: String
        let cheapestStore: String
        let cheapestPrice: Double
        let currentPrice: Double
        // Set when both stores have unit prices in the same base unit
        let unitComparisonText: String?
        var savings: Double { max(0, currentPrice - cheapestPrice) }
    }

    private(set) var itemComparisons: [ItemComparison] = []
    private(set) var totalPotentialSavings: Double = 0

    func update(groceryItems: [GroceryItem]) {
        let comparisons = groceryItems
            .filter { $0.priceHistory.count >= 2 }
            .compactMap { buildComparison(for: $0) }
            .filter { $0.savings > 0.01 }
            .sorted { $0.savings > $1.savings }

        itemComparisons = comparisons
        totalPotentialSavings = comparisons.reduce(0) { $0 + $1.savings }
    }

    private func buildComparison(for item: GroceryItem) -> ItemComparison? {
        // Latest price + unit price per store
        var latestByStore: [String: PriceEntry] = [:]
        for entry in item.priceHistory.sorted(by: { $0.date > $1.date }) {
            let name = entry.store?.name ?? entry.receipt?.storeName ?? ""
            guard !name.isEmpty, latestByStore[name] == nil else { continue }
            latestByStore[name] = entry
        }

        guard latestByStore.count >= 2,
              let currentPrice = item.latestPrice
        else { return nil }

        // Prefer unit price comparison when all stores have it in the same base unit
        let unitEntries = latestByStore.compactMapValues { entry -> (price: Double, unitPrice: Double, unitType: String)? in
            guard let up = entry.unitPrice, let ut = entry.unitType else { return nil }
            return (price: entry.price, unitPrice: up, unitType: ut)
        }

        let allSameUnit = Set(unitEntries.values.map(\.unitType)).count == 1

        if allSameUnit, unitEntries.count >= 2,
           let cheapestUnit = unitEntries.min(by: { $0.value.unitPrice < $1.value.unitPrice }),
           let currentUnitPrice = item.latestUnitPrice,
           let unitType = item.latestUnitType,
           currentUnitPrice > cheapestUnit.value.unitPrice + 0.0005 {

            let cheapestEntry = latestByStore[cheapestUnit.key]
            let cheapestPrice = cheapestEntry?.price ?? cheapestUnit.value.price

            guard currentPrice > cheapestPrice + 0.01 else { return nil }

            let fmt: (Double) -> String = { up in
                String(format: up < 0.10 ? "$%.3f" : "$%.2f", up)
            }
            let pctSavings = (currentUnitPrice - cheapestUnit.value.unitPrice) / currentUnitPrice * 100
            let text = "\(cheapestUnit.key): \(fmt(cheapestUnit.value.unitPrice))/\(unitType) " +
                       "vs current: \(fmt(currentUnitPrice))/\(unitType) — " +
                       "save \(String(format: "%.0f%%", pctSavings)) at \(cheapestUnit.key)"

            return ItemComparison(
                itemName: item.name,
                cheapestStore: cheapestUnit.key,
                cheapestPrice: cheapestPrice,
                currentPrice: currentPrice,
                unitComparisonText: text
            )
        }

        // Fall back to total price comparison
        let priceByStore = latestByStore.mapValues(\.price)
        guard let cheapest = priceByStore.min(by: { $0.value < $1.value }),
              currentPrice > cheapest.value + 0.01
        else { return nil }

        return ItemComparison(
            itemName: item.name,
            cheapestStore: cheapest.key,
            cheapestPrice: cheapest.value,
            currentPrice: currentPrice,
            unitComparisonText: nil
        )
    }
}
