import Foundation

struct ParsedReceiptItem: Identifiable {
    var id = UUID()
    var name: String
    var price: Double
    var quantity: Double = 1
    var unitPrice: Double? = nil
    var unitType: String? = nil
    var isIncluded: Bool = true
    /// Top-level ItemCategory.rawValue. nil means "not yet classified" — CategoryTagger is the fallback on save.
    var category: String? = nil
    /// Grocery sub-category (e.g. "Dairy", "Produce"). Only meaningful when category == "Grocery".
    var subCategory: String? = nil

    var itemCategory: ItemCategory {
        guard let cat = category else { return .other }
        return ItemCategory(rawValue: cat) ?? .other
    }
}

struct ParsedReceipt {
    var storeName: String
    var storeAddress: String? = nil
    var date: Date = .now
    var items: [ParsedReceiptItem]
    var detectedTotal: Double?    // receipt grand total (backend receiptTotal or OCR-extracted)
    var receiptSubtotal: Double?  // pre-tax subtotal from backend
    var salesTax: Double?         // sales tax from backend
    var isManualEntry: Bool = false
    var usedAI: Bool = false
}
