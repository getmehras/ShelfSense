import Foundation
import SwiftData

@Model
final class PriceEntry {
    var price: Double
    var unitPrice: Double?
    var unitType: String?
    var quantity: Double
    var date: Date
    var store: Store?
    var receipt: Receipt?
    var groceryItem: GroceryItem?

    init(
        price: Double,
        unitPrice: Double? = nil,
        unitType: String? = nil,
        quantity: Double = 1,
        date: Date = .now
    ) {
        self.price = price
        self.unitPrice = unitPrice
        self.unitType = unitType
        self.quantity = quantity
        self.date = date
    }
}
