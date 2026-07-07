import Foundation
import SwiftData

@Observable
final class DashboardViewModel {

    // MARK: - Summary
    private(set) var monthlySpend: Double = 0
    private(set) var monthlyChangePercent: Double? = nil
    private(set) var priceAlertItems: [GroceryItem] = []
    private(set) var recentReceipts: [Receipt] = []
    private(set) var projectedMonthTotal: Double? = nil

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

    private(set) var monthlySpends: [MonthlySpend] = []
    private(set) var historicalMonthlySpends: [MonthlySpend] = []
    private(set) var storeSpends: [StoreSpend] = []

    // MARK: - Budget

    enum BudgetStatus {
        case underBudget   // < 80%
        case approaching   // 80–99%
        case exceeded      // ≥ 100%
    }

    func budgetStatus(for budget: Double) -> BudgetStatus {
        let pct = budget > 0 ? monthlySpend / budget : 0
        if pct >= 1.0 { return .exceeded }
        if pct >= 0.80 { return .approaching }
        return .underBudget
    }

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
        monthlyChangePercent = (lastMonthTotal > 0 && !thisMonthReceipts.isEmpty)
            ? ((monthlySpend - lastMonthTotal) / lastMonthTotal) * 100
            : nil
        priceAlertItems = groceryItems.filter { $0.isPriceAlert }
        recentReceipts = Array(receipts.sorted { $0.date > $1.date }.prefix(3))

        // --- 6-month trend (dashboard compact chart) ---
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM"
        monthlySpends = (0..<6).reversed().map { offset in
            let date = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            let total = receipts
                .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
                .reduce(0) { $0 + $1.totalAmount }
            return MonthlySpend(
                month: date,
                label: shortFormatter.string(from: date),
                total: total,
                isCurrent: offset == 0
            )
        }

        // --- Full history (detail chart) — all time, oldest → newest ---
        // The chart view applies a range filter (3M / 1Y / 2Y / Max) on top of this.
        let longFormatter = DateFormatter()
        longFormatter.dateFormat = "MMM ''yy"
        if let earliest = receipts.min(by: { $0.date < $1.date })?.date {
            let startComps = calendar.dateComponents([.year, .month], from: earliest)
            var cursor     = calendar.date(from: startComps) ?? earliest
            let endComps   = calendar.dateComponents([.year, .month], from: now)
            let monthEnd   = calendar.date(from: endComps) ?? now
            var history: [MonthlySpend] = []
            while cursor <= monthEnd {
                let total = receipts
                    .filter { calendar.isDate($0.date, equalTo: cursor, toGranularity: .month) }
                    .reduce(0) { $0 + $1.totalAmount }
                history.append(MonthlySpend(
                    month: cursor,
                    label: longFormatter.string(from: cursor),
                    total: total,
                    isCurrent: calendar.isDate(cursor, equalTo: now, toGranularity: .month)
                ))
                guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
                cursor = next
            }
            historicalMonthlySpends = history
        } else {
            historicalMonthlySpends = []
        }

        // --- Store breakdown (top 5) ---
        var byStore: [String: Double] = [:]
        for receipt in receipts { byStore[receipt.storeName, default: 0] += receipt.totalAmount }
        storeSpends = byStore
            .map { StoreSpend(id: $0.key, name: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }

        // --- Spend projection ---
        // Guard: need at least day 2 of the month and some spend to produce a meaningful rate.
        let dayOfMonth = calendar.component(.day, from: now)
        let totalDays  = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        if dayOfMonth > 1, monthlySpend > 0 {
            projectedMonthTotal = (monthlySpend / Double(dayOfMonth)) * Double(totalDays)
        } else {
            projectedMonthTotal = nil
        }

    }
}
