import SwiftUI
import SwiftData

@Observable
final class ScanViewModel {
    var isShowingCamera = false
    var isShowingReview = false
    var isProcessing = false
    var isUsingAI = false
    var parsedReceipt: ParsedReceipt?
    var errorMessage: String?
    var scanValidationError: ReceiptScanValidator.FailureReason? = nil

    private let parser = ReceiptParser()

    func processScannedImages(_ images: [UIImage]) {
        isShowingCamera = false
        isProcessing = true
        isUsingAI = ScanLimitManager.shared.hasAIScansRemaining
        Task {
            let scanResult = await parser.parse(images: images)
            isProcessing = false
            switch scanResult {
            case .success(let receipt):
                parsedReceipt = receipt
                isUsingAI = receipt.usedAI
                isShowingReview = !receipt.items.isEmpty
                if receipt.items.isEmpty {
                    errorMessage = "No items could be detected. Try scanning again or use manual entry."
                }
            case .validationFailed(let reason):
                scanValidationError = reason
            case .backendError(let message):
                errorMessage = message
            }
        }
    }

    func saveReceipt(_ parsed: ParsedReceipt, context: ModelContext) {
        // Request notification permission on first save (non-blocking)
        NotificationService.shared.requestPermissionIfNeeded()

        let store: Store
        do {
            store = try findOrCreateStore(
                name: parsed.storeName,
                address: parsed.storeAddress,
                context: context
            )
        } catch {
            errorMessage = "Could not save receipt: database read failed."
            return
        }
        let storeName = store.name

        // Create the Receipt
        let receipt = Receipt(
            storeName: storeName,
            date: parsed.date,
            totalAmount: parsed.items.filter(\.isIncluded).reduce(0) { $0 + $1.price }
        )
        receipt.store = store
        context.insert(receipt)

        // Fetch all existing items once so fuzzy matching works across the whole receipt
        var existingItems: [GroceryItem]
        do {
            existingItems = try context.fetch(FetchDescriptor<GroceryItem>())
        } catch {
            errorMessage = "Could not save receipt: database read failed."
            return
        }
        var priceIncreases: [NotificationService.PriceIncrease] = []

        // Save each included item
        for parsedItem in parsed.items where parsedItem.isIncluded {
            let groceryItem: GroceryItem
            let previousPrice: Double?

            if let match = ItemMatcher.findMatch(for: parsedItem.name, in: existingItems) {
                groceryItem = match
                previousPrice = match.latestPrice  // capture BEFORE new entry is added
            } else {
                // Prefer AI-provided category/subCategory (set in Part 2); fall back to local tagger.
                let tagResult = CategoryTagger.classify(parsedItem.name)
                let gi = GroceryItem(
                    name: parsedItem.name,
                    normalizedName: ItemMatcher.normalize(parsedItem.name),
                    category: parsedItem.category ?? tagResult.category,
                    subCategory: parsedItem.subCategory ?? tagResult.subCategory
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

            // Collect price increases >= 10% — notification fires after all items are saved
            if let prev = previousPrice, NotificationService.shouldTriggerAlert(oldPrice: prev, newPrice: parsedItem.price) {
                let changePct = Int(((parsedItem.price - prev) / prev) * 100)
                priceIncreases.append(
                    NotificationService.PriceIncrease(itemName: groceryItem.name, changePct: changePct)
                )
            }
        }

        // One grouped notification for all increases from this scan
        NotificationService.shared.scheduleGroupedPriceAlert(
            increases: priceIncreases,
            storeName: storeName
        )

        isShowingReview = false
        parsedReceipt = nil
    }

    // MARK: - Store matching

    private func findOrCreateStore(
        name: String,
        address: String?,
        context: ModelContext
    ) throws -> Store {
        let normalizedName = StoreNameNormalizer.normalize(name)
        let rawAddress: String? = address.flatMap {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }

        // Primary path: match by normalizedName (stable identity key).
        // Fallback: match by name for legacy records where normalizedName == "" (pre-migration stores).
        let descriptor = FetchDescriptor<Store>(
            predicate: #Predicate {
                $0.normalizedName == normalizedName ||
                ($0.normalizedName == "" && $0.name == normalizedName)
            }
        )
        let candidates = try context.fetch(descriptor)

        // Backfill normalizedName for any legacy stores found via the fallback path.
        for store in candidates where store.normalizedName.isEmpty {
            store.normalizedName = normalizedName
        }

        // Case 1: receipt has an address — match on name AND normalized address.
        // Normalization expands abbreviations so "123 Main St" == "123 Main Street".
        if let rawAddr = rawAddress {
            let addrKey = StoreNameNormalizer.normalizeAddress(rawAddr)
            if let match = candidates.first(where: {
                StoreNameNormalizer.normalizeAddress($0.address ?? "") == addrKey
            }) {
                return match
            }
            let s = Store(name: normalizedName)
            s.address = rawAddr
            context.insert(s)
            return s
        }

        // Case 2: no address — prefer an existing entry that also has no address.
        if let match = candidates.first(where: { ($0.address ?? "").isEmpty }) {
            return match
        }

        // Case 3: all candidates have addresses and this receipt has none.
        // Pick the most recently visited location — better heuristic than insertion order.
        if let match = candidates.max(by: { a, b in
            (a.receipts.map(\.date).max() ?? .distantPast) <
            (b.receipts.map(\.date).max() ?? .distantPast)
        }) {
            return match
        }

        // Nothing found — create name-only store.
        let s = Store(name: normalizedName)
        context.insert(s)
        return s
    }

    func dismissReview() {
        isShowingReview = false
        parsedReceipt = nil
    }
}
