import Foundation

/// Top-level item category for dashboard spend breakdowns and price-comparison gating.
///
/// Stored as its `rawValue` (a plain String) in `GroceryItem.category`, so existing
/// SwiftData rows are read back via `ItemCategory(rawValue:)` with a `.grocery` fallback
/// — no schema migration required.
enum ItemCategory: String, CaseIterable, Codable {
    case grocery      = "Grocery"
    case household    = "Household"
    case clothing     = "Clothing"
    case electronics  = "Electronics"
    case personalCare = "Personal Care"
    case other        = "Other"

    /// Single source of truth for price-comparison eligibility.
    ///
    /// Grocery and Household items have a stable cross-store identity (a gallon of milk
    /// is the same product at Walmart and Costco). Clothing, electronics, and personal
    /// care items do not — size, model, and brand make direct price comparison
    /// meaningless. Add new cases here to control comparability in one place.
    var isComparable: Bool {
        switch self {
        case .grocery, .household:
            return true
        case .clothing, .electronics, .personalCare, .other:
            return false
        }
    }

    var displayName: String { rawValue }
}
