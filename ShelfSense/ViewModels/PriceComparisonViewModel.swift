import Foundation
import SwiftData

// Shared comparison logic used by PriceHistoryView and DashboardView.
struct PriceComparisonViewModel {

    // MARK: - Output types

    struct SavingsOpportunity: Identifiable {
        let id = UUID()
        let displayName: String
        let cheapestStoreName: String
        let cheapestStoreAddress: String?
        let cheapestPrice: Double
        let mostExpensiveStoreName: String
        let mostExpensivePrice: Double
        var savings: Double { mostExpensivePrice - cheapestPrice }
    }

    struct StorePriceRow: Identifiable {
        let id = UUID()
        let storeName: String
        let storeAddress: String?
        let price: Double
        let lastDate: Date
    }

    struct ItemComparison: Identifiable {
        let id = UUID()
        let displayName: String
        let rows: [StorePriceRow]               // sorted cheapest first
        var cheapestRow: StorePriceRow? { rows.first }
        var averagePrice: Double {
            rows.isEmpty ? 0 : rows.map(\.price).reduce(0, +) / Double(rows.count)
        }
        var savings: Double { averagePrice - (cheapestRow?.price ?? 0) }
    }

    // MARK: - Fuzzy name matching (Change 4)

    static func isSameItem(_ a: String, _ b: String) -> Bool {
        let al = a.lowercased(), bl = b.lowercased()
        if al == bl { return true }
        if al.contains(bl) || bl.contains(al) { return true }

        let wordsA = Set(al.components(separatedBy: " ").filter { $0.count >= 3 })
        let wordsB = Set(bl.components(separatedBy: " ").filter { $0.count >= 3 })
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return false }

        let overlap = Double(wordsA.intersection(wordsB).count) / Double(min(wordsA.count, wordsB.count))
        return overlap >= 0.8
    }

    // MARK: - Grouping

    static func groupByName(_ items: [GroceryItem]) -> [[GroceryItem]] {
        var groups: [[GroceryItem]] = []
        for item in items {
            var placed = false
            for i in groups.indices {
                if groups[i].contains(where: { isSameItem($0.name, item.name) }) {
                    groups[i].append(item)
                    placed = true
                    break
                }
            }
            if !placed { groups.append([item]) }
        }
        return groups
    }

    // Latest price per (storeName + address) across a fuzzy-matched item group
    static func latestPriceRows(for group: [GroceryItem]) -> [StorePriceRow] {
        var latestByStore: [String: StorePriceRow] = [:]
        for item in group {
            for entry in item.priceHistory {
                guard let store = entry.store else { continue }
                let key = "\(store.name)||\(store.address ?? "")"
                if let existing = latestByStore[key] {
                    if entry.date > existing.lastDate {
                        latestByStore[key] = StorePriceRow(
                            storeName: store.name,
                            storeAddress: store.address,
                            price: entry.price,
                            lastDate: entry.date
                        )
                    }
                } else {
                    latestByStore[key] = StorePriceRow(
                        storeName: store.name,
                        storeAddress: store.address,
                        price: entry.price,
                        lastDate: entry.date
                    )
                }
            }
        }
        return Array(latestByStore.values)
    }

    // MARK: - Top savings (State A & Dashboard)

    static func topSavingsOpportunities(
        from items: [GroceryItem],
        limit: Int = 10
    ) -> [SavingsOpportunity] {
        groupByName(items).compactMap { group -> SavingsOpportunity? in
            let rows = latestPriceRows(for: group)
            guard rows.count >= 2 else { return nil }

            let prices = rows.map(\.price)
            guard let minPrice = prices.min(), let maxPrice = prices.max() else { return nil }
            let savings = maxPrice - minPrice
            guard savings >= 0.05 else { return nil }

            let cheapest = rows.min(by: { $0.price < $1.price })!
            let mostExpensive = rows.max(by: { $0.price < $1.price })!
            // Shortest name is usually the most generic/canonical display name
            let displayName = group.map(\.name).min(by: { $0.count < $1.count }) ?? group[0].name

            return SavingsOpportunity(
                displayName: displayName,
                cheapestStoreName: cheapest.storeName,
                cheapestStoreAddress: cheapest.storeAddress,
                cheapestPrice: minPrice,
                mostExpensiveStoreName: mostExpensive.storeName,
                mostExpensivePrice: maxPrice
            )
        }
        .sorted { $0.savings > $1.savings }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Search comparisons (State B)

    static func comparisons(for searchText: String, from items: [GroceryItem]) -> [ItemComparison] {
        guard !searchText.isEmpty else { return [] }
        let matching = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        guard !matching.isEmpty else { return [] }

        return groupByName(matching).compactMap { group -> ItemComparison? in
            let rows = latestPriceRows(for: group).sorted { $0.price < $1.price }
            guard !rows.isEmpty else { return nil }
            let displayName = group.map(\.name).min(by: { $0.count < $1.count }) ?? group[0].name
            return ItemComparison(displayName: displayName, rows: rows)
        }
        .sorted { $0.savings > $1.savings }
    }
}
