import Foundation
import SwiftData

@Observable
final class DashboardViewModel {

    // MARK: - Summary
    private(set) var monthlySpend: Double = 0
    private(set) var monthlyChangePercent: Double? = nil
    private(set) var priceAlertItems: [GroceryItem] = []
    private(set) var recentReceipts: [Receipt] = []
    private(set) var totalSavingsOpportunity: Double = 0

    // MARK: - Chart Data
    struct MonthlySpend: Identifiable {
        let id = UUID()
        let month: Date
        let label: String
        let total: Double
        let isCurrent: Bool
    }

    struct StoreSpend: Identifiable {
        let id: String
        let name: String
        let total: Double
    }

    struct CategorySpend: Identifiable {
        let id: String
        let category: String
        let total: Double
    }

    private(set) var monthlySpends: [MonthlySpend] = []
    private(set) var storeSpends: [StoreSpend] = []
    private(set) var categorySpends: [CategorySpend] = []

    // MARK: - Update

    func update(receipts: [Receipt], groceryItems: [GroceryItem]) {
        let calendar = Calendar.current
        let now = Date.now

        // --- Monthly summary ---
        let thisMonthReceipts = receipts.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let lastMonthTotal = receipts
            .filter { calendar.isDate($0.date, equalTo: lastMonthDate, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalAmount }

        monthlySpend = thisMonthReceipts.reduce(0) { $0 + $1.totalAmount }
        monthlyChangePercent = lastMonthTotal > 0 ? ((monthlySpend - lastMonthTotal) / lastMonthTotal) * 100 : nil
        priceAlertItems = groceryItems.filter { $0.isPriceAlert }
        recentReceipts = Array(receipts.sorted { $0.date > $1.date }.prefix(5))

        // --- 6-month trend ---
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        monthlySpends = (0..<6).reversed().map { offset in
            let date = calendar.date(byAdding: .month, value: -offset, to: now)!
            let total = receipts
                .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
                .reduce(0) { $0 + $1.totalAmount }
            return MonthlySpend(
                month: date,
                label: formatter.string(from: date),
                total: total,
                isCurrent: offset == 0
            )
        }

        // --- Store breakdown (top 5) ---
        var byStore: [String: Double] = [:]
        for receipt in receipts { byStore[receipt.storeName, default: 0] += receipt.totalAmount }
        storeSpends = byStore
            .map { StoreSpend(id: $0.key, name: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }

        // --- Category breakdown ---
        var byCategory: [String: Double] = [:]
        for item in groceryItems {
            for entry in item.priceHistory {
                byCategory[item.category, default: 0] += entry.price * entry.quantity
            }
        }
        categorySpends = byCategory
            .map { CategorySpend(id: $0.key, category: $0.key, total: $0.value) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }

        // --- Savings opportunity ---
        totalSavingsOpportunity = groceryItems.compactMap { item -> Double? in
            var latestByStore: [String: Double] = [:]
            for entry in item.priceHistory.sorted(by: { $0.date > $1.date }) {
                let name = entry.store?.name ?? entry.receipt?.storeName ?? ""
                guard !name.isEmpty, latestByStore[name] == nil else { continue }
                latestByStore[name] = entry.price
            }
            guard latestByStore.count >= 2,
                  let cheapest = latestByStore.values.min(),
                  let current = item.latestPrice,
                  current > cheapest + 0.01 else { return nil }
            return current - cheapest
        }.reduce(0, +)
    }
}
