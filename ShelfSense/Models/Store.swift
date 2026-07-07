import Foundation
import SwiftData

@Model
final class Store {
    var name: String
    /// Stable identity key — set at creation from StoreNameNormalizer, never changed by rename.
    /// Existing records migrated by SwiftData default to "" and are backfilled lazily in findOrCreateStore.
    var normalizedName: String = ""
    var location: String
    var address: String?

    @Relationship(inverse: \Receipt.store)
    var receipts: [Receipt] = []

    @Relationship(inverse: \PriceEntry.store)
    var priceEntries: [PriceEntry] = []

    init(name: String, location: String = "") {
        self.name = name
        self.normalizedName = StoreNameNormalizer.normalize(name)
        self.location = location
    }

    // Deletes the store and all its data.
    // GroceryItems tracked ONLY at this store are also deleted (they'd have no data left).
    // GroceryItems tracked at other stores are kept; only this store's entries are removed.
    func deleteWithCascade(from context: ModelContext) {
        let storeID = persistentModelID

        // Pre-compute which grocery items will become orphaned (all their price
        // entries come from this store and would be deleted with it).
        var checkedIDs = Set<PersistentIdentifier>()
        var orphanedItems: [GroceryItem] = []

        for entry in priceEntries + receipts.flatMap(\.items) {
            guard let item = entry.groceryItem,
                  !checkedIDs.contains(item.persistentModelID) else { continue }
            checkedIDs.insert(item.persistentModelID)

            let willBeOrphaned = item.priceHistory.allSatisfy {
                $0.store?.persistentModelID == storeID ||
                $0.receipt?.store?.persistentModelID == storeID
            }
            if willBeOrphaned { orphanedItems.append(item) }
        }

        // Nullify store ref on multi-store entries BEFORE any deletions.
        // Iterating priceEntries after cascades fire is undefined — apply while all objects are live.
        let orphanIDs = Set(orphanedItems.map(\.persistentModelID))
        for entry in priceEntries {
            let isOrphanEntry = entry.groceryItem.map { orphanIDs.contains($0.persistentModelID) } ?? false
            if !isOrphanEntry { entry.store = nil }
        }
        // Delete orphaned grocery items (cascade removes their price entries)
        for item in orphanedItems { context.delete(item) }
        // Delete receipts (cascade removes their price entries)
        for receipt in receipts { context.delete(receipt) }
        context.delete(self)
    }
}
