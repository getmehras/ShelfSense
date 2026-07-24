import Foundation
import SwiftData

@Model
final class GroceryItem {
    var name: String
    var normalizedName: String
    var category: String
    var subCategory: String?          // grocery sub-category (Dairy, Bakery, etc.)
    var lastAlertDismissedDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \PriceEntry.groceryItem)
    var priceHistory: [PriceEntry] = []

    var latestPrice: Double? {
        priceHistory.max(by: { $0.date < $1.date })?.price
    }

    var latestUnitPrice: Double? {
        guard let entry = priceHistory.max(by: { $0.date < $1.date }) else { return nil }
        if let up = entry.unitPrice, up > 0 { return up }
        return entry.price / (entry.quantity > 0 ? entry.quantity : 1)
    }

    var latestUnitType: String? {
        priceHistory.max(by: { $0.date < $1.date })?.unitType
    }

    var previousPrice: Double? {
        let sorted = priceHistory.sorted { $0.date > $1.date }
        return sorted.count >= 2 ? sorted[1].price : nil
    }

    var previousUnitPrice: Double? {
        let sorted = priceHistory.sorted { $0.date > $1.date }
        guard sorted.count >= 2 else { return nil }
        let entry = sorted[1]
        if let up = entry.unitPrice, up > 0 { return up }
        return entry.price / (entry.quantity > 0 ? entry.quantity : 1)
    }

    var priceChangePercent: Double? {
        guard let latest = latestUnitPrice, let previous = previousUnitPrice, previous > 0 else { return nil }
        return ((latest - previous) / previous) * 100
    }

    var isPriceAlert: Bool {
        guard (priceChangePercent ?? 0) > 10 else { return false }
        // Suppress if the user already dismissed this alert after the latest price entry
        guard let latestDate = priceHistory.max(by: { $0.date < $1.date })?.date else { return false }
        if let dismissed = lastAlertDismissedDate, dismissed >= latestDate { return false }
        return true
    }

    /// Typed view of the persisted `category` string.
    /// Unknown legacy values (e.g. "Dairy", "Bakery") fall back to `.grocery`.
    var itemCategory: ItemCategory {
        ItemCategory(rawValue: category) ?? .grocery
    }

    /// Whether this item is eligible for cross-store price comparison.
    /// Delegates entirely to `ItemCategory.isComparable` — one place to change.
    var isComparable: Bool { itemCategory.isComparable }

    /// Effective grocery sub-category, handling both new and legacy stored items.
    ///
    /// New items: `category` holds a valid ItemCategory rawValue ("Grocery"), `subCategory` holds the sub.
    /// Legacy items: `category` holds a fine-grained old value ("Dairy", "Bakery") because the old
    /// CategoryTagger stored those directly. Since `ItemCategory(rawValue:)` returns nil for them,
    /// we expose the old value as the sub-category rather than losing the detail.
    var grocerySubCategory: String? {
        if let sc = subCategory { return sc }
        // Legacy: `category` holds a value that isn't a valid ItemCategory rawValue — it IS the sub-category
        if ItemCategory(rawValue: category) == nil, category != "General" {
            return category
        }
        return nil
    }

    init(name: String, normalizedName: String, category: String = ItemCategory.grocery.rawValue, subCategory: String? = nil) {
        self.name = name
        self.normalizedName = normalizedName
        self.category = category
        self.subCategory = subCategory
    }
}
