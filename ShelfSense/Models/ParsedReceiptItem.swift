import Foundation

struct ParsedReceiptItem: Identifiable {
    var id = UUID()
    var name: String
    var price: Double
    var quantity: Double = 1
    var unitPrice: Double? = nil
    var unitType: String? = nil
    var isIncluded: Bool = true
}

struct ParsedReceipt {
    var storeName: String
    var date: Date = .now
    var items: [ParsedReceiptItem]
    var detectedTotal: Double?
    var isManualEntry: Bool = false
}
