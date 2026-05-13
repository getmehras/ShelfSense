import SwiftUI
import SwiftData

@Observable
final class ScanViewModel {
    var isShowingCamera = false
    var isShowingReview = false
    var isProcessing = false
    var parsedReceipt: ParsedReceipt?
    var errorMessage: String?

    private let parser = ReceiptParser()

    func processScannedImages(_ images: [UIImage]) {
        isShowingCamera = false
        isProcessing = true
        Task {
            let result = await parser.parse(images: images)
            parsedReceipt = result
            isProcessing = false
            isShowingReview = !result.items.isEmpty
            if result.items.isEmpty {
                errorMessage = "No items could be detected. Try scanning again or use manual entry."
            }
        }
    }

    func saveReceipt(_ parsed: ParsedReceipt, context: ModelContext) {
        // Request notification permission on first save (non-blocking)
        NotificationService.shared.requestPermissionIfNeeded()

        let storeName = parsed.storeName

        // Find or create the Store
        let storeDescriptor = FetchDescriptor<Store>(
            predicate: #Predicate { $0.name == storeName }
        )
        let store = (try? context.fetch(storeDescriptor))?.first ?? {
            let s = Store(name: storeName)
            context.insert(s)
            return s
        }()

        // Create the Receipt
        let receipt = Receipt(
            storeName: storeName,
            date: parsed.date,
            totalAmount: parsed.items.filter(\.isIncluded).reduce(0) { $0 + $1.price * $1.quantity }
        )
        receipt.store = store
        context.insert(receipt)

        // Fetch all existing items once so fuzzy matching works across the whole receipt
        var existingItems = (try? context.fetch(FetchDescriptor<GroceryItem>())) ?? []

        // Save each included item
        for parsedItem in parsed.items where parsedItem.isIncluded {
            let groceryItem: GroceryItem
            let previousPrice: Double?

            if let match = ItemMatcher.findMatch(for: parsedItem.name, in: existingItems) {
                groceryItem = match
                previousPrice = match.latestPrice  // capture BEFORE new entry is added
            } else {
                let gi = GroceryItem(
                    name: parsedItem.name,
                    normalizedName: ItemMatcher.normalize(parsedItem.name),
                    category: CategoryTagger.category(for: parsedItem.name)
                )
                context.insert(gi)
                existingItems.append(gi)
                groceryItem = gi
                previousPrice = nil
            }

            let entry = PriceEntry(
                price: parsedItem.price,
                unitPrice: parsedItem.unitPrice,
                unitType: parsedItem.unitType,
                quantity: parsedItem.quantity,
                date: parsed.date
            )
            entry.store = store
            entry.receipt = receipt
            entry.groceryItem = groceryItem
            context.insert(entry)

            // Fire a notification if the price increased more than 10%
            if let prev = previousPrice {
                NotificationService.shared.schedulePriceAlert(
                    itemName: groceryItem.name,
                    storeName: storeName,
                    oldPrice: prev,
                    newPrice: parsedItem.price
                )
            }
        }

        isShowingReview = false
        parsedReceipt = nil
    }

    func dismissReview() {
        isShowingReview = false
        parsedReceipt = nil
    }
}
