import SwiftUI
import SwiftData

@Observable
final class ScanViewModel {
    var isShowingCamera = false
    var isShowingReview = false
    var isShowingDebug = false
    var isProcessing = false
    var isUsingAI = false
    var parsedReceipt: ParsedReceipt?
    var lastDebugInfo: ParseDebugInfo?
    var errorMessage: String?
    var scanValidationError: ReceiptScanValidator.FailureReason? = nil

    private let parser = ReceiptParser()

    private var debugModeOn: Bool {
        UserDefaults.standard.bool(forKey: "showParseDebug")
    }

    func processScannedImages(_ images: [UIImage]) {
        isShowingCamera = false
        isProcessing = true
        isUsingAI = ScanLimitManager.shared.hasAIScansRemaining && !debugModeOn
        Task {
            if debugModeOn {
                let (result, debugInfo) = await parser.parseWithDebug(images: images)
                parsedReceipt = result
                lastDebugInfo = debugInfo
                isProcessing = false
                isUsingAI = false
                isShowingDebug = true
            } else {
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
                }
            }
        }
    }

    func proceedToReviewFromDebug() {
        isShowingDebug = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.isShowingReview = !(self.parsedReceipt?.items.isEmpty ?? true)
        }
    }

    func saveReceipt(_ parsed: ParsedReceipt, context: ModelContext) {
        // Request notification permission on first save (non-blocking)
        NotificationService.shared.requestPermissionIfNeeded()

        let store = findOrCreateStore(
            name: parsed.storeName,
            address: parsed.storeAddress,
            context: context
        )
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
        var existingItems = (try? context.fetch(FetchDescriptor<GroceryItem>())) ?? []
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
    ) -> Store {
        let normalizedName = StoreNameNormalizer.normalize(name)
        let normalizedAddress: String? = (address?.isEmpty == false) ? address : nil

        // Fetch all stores sharing this normalized name
        let descriptor = FetchDescriptor<Store>(
            predicate: #Predicate { $0.name == normalizedName }
        )
        let candidates = (try? context.fetch(descriptor)) ?? []

        // Case 1: receipt has an address — match on name AND address (case-insensitive)
        if let addr = normalizedAddress {
            let addrKey = addr.lowercased().trimmingCharacters(in: .whitespaces)
            if let match = candidates.first(where: {
                ($0.address ?? "").lowercased().trimmingCharacters(in: .whitespaces) == addrKey
            }) {
                return match
            }
            // Different address (or no existing address entry) — new store location
            let s = Store(name: normalizedName)
            s.address = addr
            context.insert(s)
            return s
        }

        // Case 2: no address — prefer an existing entry that also has no address
        if let match = candidates.first(where: { $0.address == nil || $0.address?.isEmpty == true }) {
            return match
        }

        // Case 3: name match exists but has an address — reuse rather than creating a bare duplicate
        if let match = candidates.first {
            return match
        }

        // Nothing found — create name-only store
        let s = Store(name: normalizedName)
        context.insert(s)
        return s
    }

    func dismissReview() {
        isShowingReview = false
        parsedReceipt = nil
    }
}
