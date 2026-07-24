import SwiftUI
import SwiftData
import Charts

struct StoreDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: Store
    @Query private var allStores: [Store]

    @AppStorage("price_compare_active") private var priceCompareActive = false
    @AppStorage("selected_tab") private var selectedTab = 0

    @State private var isRenaming = false
    @State private var pendingName = ""
    @State private var isConfirmingDelete = false

    // MARK: - Derived data

    private var displayAddress: String? {
        if let a = store.address, !a.isEmpty { return a }
        if !store.location.isEmpty { return store.location }
        return nil
    }

    private var totalSpend: Double { store.receipts.reduce(0) { $0 + $1.totalAmount } }
    private var sortedReceipts: [Receipt] { store.receipts.sorted { $0.date > $1.date } }

    private var storeItems: [StoreItemSummary] {
        var grouped: [PersistentIdentifier: (item: GroceryItem, entries: [PriceEntry])] = [:]
        for entry in store.priceEntries {
            guard let item = entry.groceryItem else { continue }
            let key = item.persistentModelID
            if grouped[key] == nil { grouped[key] = (item: item, entries: []) }
            grouped[key]!.entries.append(entry)
        }
        return grouped.values
            .map { StoreItemSummary(item: $0.item, entries: $0.entries) }
            .sorted { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }
    }

    private var categorySpends: [(category: String, total: Double)] {
        var byCategory: [String: Double] = [:]
        for summary in storeItems {
            // Use grocery sub-category when available (Dairy, Meat, Produce, etc.)
            // so the chart shows meaningful breakdowns instead of one "Grocery" bar.
            let cat: String
            if summary.item.itemCategory == .grocery, let sub = summary.item.grocerySubCategory {
                cat = sub
            } else {
                cat = summary.item.itemCategory.displayName
            }
            for entry in summary.entries {
                byCategory[cat, default: 0] += entry.price
            }
        }
        return byCategory
            .map { (category: $0.key, total: $0.value) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    // Items where THIS store is cheaper than the average price at other stores
    private var bestPriceItems: [BestPriceItem] {
        guard allStores.count >= 2 else { return [] }
        return storeItems.compactMap { summary -> BestPriceItem? in
            guard let priceHere = summary.lastPrice else { return nil }
            var latestByOtherStore: [PersistentIdentifier: Double] = [:]
            for entry in summary.item.priceHistory.sorted(by: { $0.date > $1.date }) {
                guard let s = entry.store, s.persistentModelID != store.persistentModelID else { continue }
                let sid = s.persistentModelID
                if latestByOtherStore[sid] == nil { latestByOtherStore[sid] = entry.price }
            }
            guard !latestByOtherStore.isEmpty else { return nil }
            let avgElsewhere = latestByOtherStore.values.reduce(0, +) / Double(latestByOtherStore.count)
            guard priceHere < avgElsewhere - 0.01 else { return nil }
            return BestPriceItem(itemName: summary.item.name, priceHere: priceHere, avgElsewhere: avgElsewhere)
        }
        .sorted { ($0.avgElsewhere - $0.priceHere) > ($1.avgElsewhere - $1.priceHere) }
        .prefix(5)
        .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NavBarCurve()

                if store.receipts.isEmpty {
                    emptyState
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                } else {
                    headerSection
                        .padding(.horizontal, 16)

                    if !storeItems.isEmpty {
                        SectionHeader(title: "Items Purchased Here")
                        itemsCard
                            .padding(.horizontal, 16)
                    }

                    if !categorySpends.isEmpty {
                        SectionHeader(title: "Spending by Category")
                        categoryChartCard
                            .padding(.horizontal, 16)
                    }

                    if !bestPriceItems.isEmpty {
                        SectionHeader(title: "Best Prices Here")
                        bestPricesCard
                            .padding(.horizontal, 16)
                    }

                    SectionHeader(title: "Trip History")
                    tripHistoryCard
                        .padding(.horizontal, 16)

                    comparePricesButton
                        .padding(.horizontal, 16)

                    deleteButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                }
            }
        }
        .background(Theme.appBackground)
        .greenNavTitle(store.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rename") {
                    pendingName = store.name
                    isRenaming = true
                }
                .accessibilityLabel("Rename this store")
            }
        }
        .alert("Delete \(store.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete Store & All Trips", role: .destructive) {
                store.deleteWithCascade(from: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = store.receipts.count
            Text("This will permanently delete \(store.name) and \(count) trip\(count == 1 ? "" : "s") with all price data. This cannot be undone.")
        }
        .alert("Rename Store", isPresented: $isRenaming) {
            TextField("Store name", text: $pendingName)
                .accessibilityLabel("New store name")
            Button("Save") {
                let trimmed = pendingName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                store.name = trimmed
                for receipt in store.receipts { receipt.storeName = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - 1. Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                StoreAvatar(name: store.name, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    if let address = displayAddress {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                StatPill(label: "\(store.receipts.count) trip\(store.receipts.count == 1 ? "" : "s")")
                StatPill(label: "\(totalSpend.formatted(.currency(code: "USD"))) total")
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.name), \(store.receipts.count) trips, \(totalSpend.formatted(.currency(code: "USD"))) total")
    }

    // MARK: - 2. Items Section

    private var itemsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(storeItems.enumerated()), id: \.element.id) { index, summary in
                StoreItemRow(summary: summary)
                if index < storeItems.count - 1 {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - 3. Best Prices Section

    private var bestPricesCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(bestPriceItems.enumerated()), id: \.element.id) { index, item in
                BestPriceRow(item: item)
                if index < bestPriceItems.count - 1 {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Category Chart

    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All time at \(store.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart(categorySpends, id: \.category) { item in
                BarMark(
                    x: .value("Amount", item.total),
                    y: .value("Category", item.category)
                )
                .foregroundStyle(Theme.mint.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(format: .currency(code: "USD"), values: .automatic(desiredCount: 4))
            }
            .frame(height: min(max(48, CGFloat(categorySpends.count) * 44), 320))
            .accessibilityLabel("Horizontal bar chart showing spending by category at \(store.name)")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Trip History

    private var tripHistoryCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedReceipts.enumerated()), id: \.element.id) { index, receipt in
                ReceiptSummaryRow(receipt: receipt)
                if index < sortedReceipts.count - 1 {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - 4. Compare Prices Button

    private var comparePricesButton: some View {
        Button {
            priceCompareActive = true
            selectedTab = 2
        } label: {
            HStack(spacing: 6) {
                Text("Compare Prices With Other Stores")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.mint)
            .clipShape(Capsule())
        }
        .accessibilityLabel("Compare prices at \(store.name) with other stores")
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Delete Store", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(Color.red.opacity(0.08))
        .foregroundStyle(.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Delete \(store.name) and all its trip history")
    }

    // MARK: - 5. Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Theme.mint)
            Text("No items yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Scan a receipt from \(store.name) to start tracking prices here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            NavigationLink(destination: ScanView()) {
                Text("Scan Receipt")
            }
            .buttonStyle(.mint)
            .padding(.horizontal, 48)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Data models

private struct StoreItemSummary: Identifiable {
    let item: GroceryItem
    let entries: [PriceEntry]

    var id: PersistentIdentifier { item.persistentModelID }
    var purchaseCount: Int { entries.count }
    var lastPrice: Double? { entries.max(by: { $0.date < $1.date })?.price }
    var firstPrice: Double? { entries.min(by: { $0.date < $1.date })?.price }
    var lastDate: Date? { entries.max(by: { $0.date < $1.date })?.date }

    enum Trend { case up, down, flat }
    var trend: Trend {
        guard let first = firstPrice, let last = lastPrice, entries.count > 1 else { return .flat }
        if last > first + 0.01 { return .up }
        if last < first - 0.01 { return .down }
        return .flat
    }
}

private struct BestPriceItem: Identifiable {
    let id = UUID()
    let itemName: String
    let priceHere: Double
    let avgElsewhere: Double
}

// MARK: - Subviews

private struct StatPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.primary.opacity(0.08))
            .clipShape(Capsule())
    }
}

private struct StoreItemRow: View {
    let summary: StoreItemSummary

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.item.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(summary.purchaseCount)× purchased")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let price = summary.lastPrice {
                Text(price, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
            }

            trendView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(summary.item.name), purchased \(summary.purchaseCount) times, last price \(summary.lastPrice.map { $0.formatted(.currency(code: "USD")) } ?? "")"
        )
    }

    @ViewBuilder
    private var trendView: some View {
        switch summary.trend {
        case .up:
            Image(systemName: "arrow.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
                .frame(width: 18)
        case .down:
            Image(systemName: "arrow.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.mint)
                .frame(width: 18)
        case .flat:
            Color.clear.frame(width: 18)
        }
    }
}

private struct BestPriceRow: View {
    let item: BestPriceItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
                .frame(width: 20)

            Text(item.itemName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.priceHere, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.mint)
                Text("avg elsewhere \(item.avgElsewhere.formatted(.currency(code: "USD")))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.itemName), \(item.priceHere.formatted(.currency(code: "USD"))) here, average \(item.avgElsewhere.formatted(.currency(code: "USD"))) elsewhere")
    }
}

private struct ReceiptSummaryRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.primary.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "receipt.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.date, format: .dateTime.month(.wide).day().year())
                    .font(.subheadline.weight(.medium))
                Text("\(receipt.items.count) item\(receipt.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(receipt.totalAmount, format: .currency(code: "USD"))
                .font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(receipt.date.formatted(.dateTime.month().day().year())), \(receipt.items.count) items, \(receipt.totalAmount.formatted(.currency(code: "USD")))")
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Schema([Store.self, Receipt.self, PriceEntry.self, GroceryItem.self]),
        configurations: config
    )
    let ctx = container.mainContext
    let cal = Calendar.current

    let store = Store(name: "HEB")
    store.address = "3750 Gattis School Rd, Round Rock TX"
    ctx.insert(store)

    let other = Store(name: "Walmart")
    ctx.insert(other)

    for (days, total) in [(-2, 54.92), (-9, 62.10), (-23, 48.30), (-37, 71.20)] {
        let r = Receipt(
            storeName: store.name,
            date: cal.date(byAdding: .day, value: days, to: .now)!,
            totalAmount: total
        )
        r.store = store; ctx.insert(r)
    }

    let milk    = GroceryItem(name: "Organic Milk",      normalizedName: "organic milk",      category: "Dairy"); ctx.insert(milk)
    let eggs    = GroceryItem(name: "Free Range Eggs",   normalizedName: "free range eggs",   category: "Dairy"); ctx.insert(eggs)
    let chicken = GroceryItem(name: "Chicken Breast",    normalizedName: "chicken breast",    category: "Meat");  ctx.insert(chicken)
    let apples  = GroceryItem(name: "Granny Smith Apples", normalizedName: "granny smith",   category: "Produce"); ctx.insert(apples)

    for (item, prices) in [
        (milk,    [3.29, 3.39, 3.49]),
        (eggs,    [4.99, 5.29]),
        (chicken, [8.99]),
        (apples,  [3.49, 3.29]),
    ] as [(GroceryItem, [Double])] {
        for (i, price) in prices.enumerated() {
            let e = PriceEntry(price: price, date: cal.date(byAdding: .day, value: -(prices.count - i) * 9, to: .now)!)
            e.store = store; e.groceryItem = item; ctx.insert(e)
        }
    }

    for (item, price) in [(milk, 3.79), (eggs, 5.49), (chicken, 9.49), (apples, 3.89)] as [(GroceryItem, Double)] {
        let e = PriceEntry(price: price, date: cal.date(byAdding: .day, value: -4, to: .now)!)
        e.store = other; e.groceryItem = item; ctx.insert(e)
    }

    return NavigationStack { StoreDetailView(store: store) }.modelContainer(container)
}
