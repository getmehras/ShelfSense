import Foundation
import SwiftData

@Model
final class Receipt {
    var storeName: String
    var date: Date
    var totalAmount: Double
    var store: Store?

    @Relationship(deleteRule: .cascade, inverse: \PriceEntry.receipt)
    var items: [PriceEntry] = []

    init(storeName: String, date: Date = .now, totalAmount: Double = 0) {
        self.storeName = storeName
        self.date = date
        self.totalAmount = totalAmount
    }
}
