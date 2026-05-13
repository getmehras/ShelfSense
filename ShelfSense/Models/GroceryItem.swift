import Foundation
import SwiftData

@Model
final class GroceryItem {
    var name: String
    var normalizedName: String
    var category: String
    var lastAlertDismissedDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \PriceEntry.groceryItem)
    var priceHistory: [PriceEntry] = []

    var latestPrice: Double? {
        priceHistory.max(by: { $0.date < $1.date })?.price
    }

    var latestUnitPrice: Double? {
        priceHistory.max(by: { $0.date < $1.date })?.unitPrice
    }

    var latestUnitType: String? {
        priceHistory.max(by: { $0.date < $1.date })?.unitType
    }

    var previousPrice: Double? {
        let sorted = priceHistory.sorted { $0.date > $1.date }
        return sorted.count >= 2 ? sorted[1].price : nil
    }

    var priceChangePercent: Double? {
        guard let latest = latestPrice, let previous = previousPrice, previous > 0 else { return nil }
        return ((latest - previous) / previous) * 100
    }

    var isPriceAlert: Bool {
        guard (priceChangePercent ?? 0) > 10 else { return false }
        // Suppress if the user already dismissed this alert after the latest price entry
        guard let latestDate = priceHistory.max(by: { $0.date < $1.date })?.date else { return false }
        if let dismissed = lastAlertDismissedDate, dismissed >= latestDate { return false }
        return true
    }

    init(name: String, normalizedName: String, category: String = "General") {
        self.name = name
        self.normalizedName = normalizedName
        self.category = category
    }
}
