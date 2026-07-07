import SwiftUI
import SwiftData

struct PriceHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [GroceryItem]

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .unitPrice
    @State private var priceMode: PriceMode = .history
    @State private var itemToDelete: GroceryItem?

    // Set by Dashboard "See All" button to deep-link into compare mode
    @AppStorage("price_compare_active") private var priceCompareActive = false
    @FocusState private var searchFocused: Bool

    // MARK: - Enums

    enum SortOrder: String, CaseIterable {
        case unitPrice = "Unit Price"
        case price     = "Price"
        case name      = "Name"
    }

    enum PriceMode: String, CaseIterable {
        case history = "History"
        case compare = "Compare"
    }

    // MARK: - History mode data

    private var sortedFilteredItems: [GroceryItem] {
        let base = searchText.isEmpty
            ? items
            : items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        return base.sorted { a, b in
            switch sortOrder {
            case .unitPrice:
                switch (a.latestUnitPrice, b.latestUnitPrice) {
                case (let ua?, let ub?): return ua < ub
                case (.some, .none):     return true
                case (.none, .some):     return false
                case (.none, .none):     return a.name < b.name
                }
            case .price:
                switch (a.latestPrice, b.latestPrice) {
                case (let pa?, let pb?): return pa < pb
                case (.some, .none):     return true
                case (.none, .some):     return false
                case (.none, .none):     return a.name < b.name
                }
            case .name:
                return a.name < b.name
            }
        }
    }

    // MARK: - Compare mode data

    private var savingsOpportunities: [PriceComparisonViewModel.SavingsOpportunity] {
        PriceComparisonViewModel.topSavingsOpportunities(from: items, limit: 10)
    }

    private var searchComparisons: [PriceComparisonViewModel.ItemComparison] {
        PriceComparisonViewModel.comparisons(for: searchText, from: items)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    NavBarCurve()
                    searchBar
                    modePicker

                    if priceMode == .history {
                        historyContent
                    } else {
                        compareContent
                    }

                    Spacer(minLength: 24)
                }
            }
            .background(Theme.appBackground)
            .greenNavTitle("Price History")
        }
        .alert(
            "Delete \(itemToDelete?.name ?? "Item")?",
            isPresented: Binding(get: { itemToDelete != nil }, set: { if !$0 { itemToDelete = nil } })
        ) {
            Button("Delete Item & Price History", role: .destructive) {
                if let item = itemToDelete { modelContext.delete(item) }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) { itemToDelete = nil }
        } message: {
            if let item = itemToDelete {
                Text("This will permanently delete \(item.name) and all \(item.priceHistory.count) price record\(item.priceHistory.count == 1 ? "" : "s"). This cannot be undone.")
            }
        }
        .onAppear {
            if priceCompareActive {
                priceMode = .compare
                priceCompareActive = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchFocused = true
                }
            }
        }
    }

    // MARK: - Shared controls

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(priceMode == .history ? "Search items…" : "Search to compare…", text: $searchText)
                .font(.body)
                .focused($searchFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $priceMode) {
            ForEach(PriceMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var sortPicker: some View {
        HStack(spacing: 8) {
            Text("Sort:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Sort by", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - History mode (unchanged from original)

    @ViewBuilder
    private var historyContent: some View {
        sortPicker

        if items.isEmpty {
            emptyState
        } else if sortedFilteredItems.isEmpty {
            noResultsState
        } else {
            ForEach(sortedFilteredItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    ItemCard(item: item)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .contextMenu {
                    Button(role: .destructive) {
                        itemToDelete = item
                    } label: {
                        Label("Delete Item", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Compare mode

    @ViewBuilder
    private var compareContent: some View {
        if searchText.isEmpty {
            compareStateA
        } else {
            compareStateB
        }
    }

    // State A — no search: top savings opportunities
    @ViewBuilder
    private var compareStateA: some View {
        if savingsOpportunities.isEmpty {
            compareEmptyState
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Best Deals Across Your Stores")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                Text("Items where prices vary most between stores")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }

            ForEach(savingsOpportunities) { opportunity in
                SavingsOpportunityRow(opportunity: opportunity)
                    .padding(.horizontal, 16)
            }
        }
    }

    // State B — with search: grouped store comparison
    @ViewBuilder
    private var compareStateB: some View {
        if searchComparisons.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.mint)
                Text("No items found matching \"\(searchText)\"")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .padding(.horizontal, 32)
        } else {
            ForEach(searchComparisons) { comparison in
                ItemComparisonSection(comparison: comparison)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tag.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Theme.mint)
            Text("Nothing tracked yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Your price history will appear here after you scan receipts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            NavigationLink(destination: ScanView()) {
                Text("Scan Your First Receipt")
            }
            .buttonStyle(.mint)
            .padding(.horizontal, 32)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Theme.mint)
            Text("No results for \"\(searchText)\"")
                .font(.headline)
            Text("Try a different search term.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var compareEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Theme.mint)
            Text("Nothing to compare yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Scan receipts from at least 2 different stores to compare prices and find the best deals.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }
}

// MARK: - Compare subviews

private struct SavingsOpportunityRow: View {
    let opportunity: PriceComparisonViewModel.SavingsOpportunity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(opportunity.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))

            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text(opportunity.cheapestStoreName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.mint)
                Text(opportunity.cheapestPrice, format: .currency(code: "USD"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mint)
                Text("vs \(opportunity.mostExpensiveStoreName) \(opportunity.mostExpensivePrice.formatted(.currency(code: "USD")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Save up to \(opportunity.savings.formatted(.currency(code: "USD"))) per unit")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.mint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(opportunity.displayName), cheapest at \(opportunity.cheapestStoreName) for \(opportunity.cheapestPrice.formatted(.currency(code: "USD"))), save up to \(opportunity.savings.formatted(.currency(code: "USD")))")
    }
}

private struct ItemComparisonSection: View {
    let comparison: PriceComparisonViewModel.ItemComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text(comparison.displayName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(.label))
                .padding(.horizontal, 4)

            // Store rows
            VStack(spacing: 0) {
                ForEach(Array(comparison.rows.enumerated()), id: \.element.id) { index, row in
                    StorePriceComparisonRow(row: row, isCheapest: index == 0)
                    if index < comparison.rows.count - 1 {
                        Divider().padding(.horizontal, 14)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)

            // Savings card — only when 2+ stores and meaningful difference
            if comparison.rows.count >= 2,
               let cheapest = comparison.cheapestRow,
               comparison.savings >= 0.05 {
                HStack(spacing: 8) {
                    Text("💰")
                    Text("Buy at \(cheapest.storeName) to save \(comparison.savings.formatted(.currency(code: "USD"))) compared to your average of \(comparison.averagePrice.formatted(.currency(code: "USD")))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(.label))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.mint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if comparison.rows.count == 1 {
                Text("Buy this at more stores to compare prices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

private struct StorePriceComparisonRow: View {
    let row: PriceComparisonViewModel.StorePriceRow
    let isCheapest: Bool

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isCheapest {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                        .font(.body)
                } else {
                    Color.clear
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.storeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCheapest ? Theme.mint : Color(.label))
                if let address = row.storeAddress, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Last bought \(row.lastDate.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(row.price, format: .currency(code: "USD"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isCheapest ? Theme.mint : Color(.label))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isCheapest ? Theme.mint.opacity(0.06) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.storeName), \(row.price.formatted(.currency(code: "USD")))\(isCheapest ? ", cheapest" : "")")
    }
}

// MARK: - Item Card (unchanged from original)

private struct ItemCard: View {
    let item: GroceryItem

    private var trendColor: Color {
        guard let change = item.priceChangePercent else { return .secondary }
        return change > 0 ? .red : Theme.mint
    }

    private var trendIcon: String {
        guard let change = item.priceChangePercent else { return "" }
        return change > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private var latestStore: String? {
        item.priceHistory
            .max(by: { $0.date < $1.date })
            .flatMap { $0.store?.name ?? $0.receipt?.storeName }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.primary.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon(item.category))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                HStack(spacing: 4) {
                    if let store = latestStore {
                        Text(store)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let price = item.latestPrice {
                    Text(price, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(.label))
                }
                if let up = item.latestUnitPrice, let ut = item.latestUnitType {
                    Text("(\(String(format: up < 0.10 ? "$%.3f" : "$%.2f", up))/\(ut))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let change = item.priceChangePercent, !trendIcon.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: trendIcon)
                            .font(.caption2.weight(.bold))
                        Text("\(abs(change), specifier: "%.0f")%")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(trendColor)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = "\(item.name), \(item.category)"
        if let price = item.latestPrice { label += ", \(price.formatted(.currency(code: "USD")))" }
        if let up = item.latestUnitPrice, let ut = item.latestUnitType { label += ", \(String(format: "$%.2f", up)) per \(ut)" }
        if item.isPriceAlert, let change = item.priceChangePercent { label += ", price alert: up \(String(format: "%.0f", change)) percent" }
        return label
    }

    private func categoryIcon(_ category: String) -> String {
        switch category.lowercased() {
        case "grocery":       return "cart.fill"
        case "household":     return "house.fill"
        case "clothing":      return "tshirt.fill"
        case "electronics":   return "bolt.fill"
        case "personal care": return "cross.case.fill"
        default:              return "tag.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Schema([GroceryItem.self, PriceEntry.self, Store.self, Receipt.self]),
        configurations: config
    )
    let ctx = container.mainContext
    let cal = Calendar.current

    let wf  = Store(name: "Whole Foods"); ctx.insert(wf)
    let wm  = Store(name: "Walmart");    ctx.insert(wm)

    for (name, cat, wfPrice, wmPrice, unitP, unitT) in [
        ("Organic Milk 64oz",     "Dairy",   6.89, 5.49, 0.108, "oz"),
        ("Free Range Eggs 12ct",  "Dairy",   5.79, 4.89, 0.483, "ea"),
        ("Sourdough Bread",       "Bakery",  4.49, 3.79, nil,   nil as String?),
        ("Baby Spinach 5oz",      "Produce", 3.99, 3.29, 0.798, "oz"),
    ] as [(String, String, Double, Double, Double?, String?)] {
        let item = GroceryItem(name: name, normalizedName: ItemMatcher.normalize(name), category: cat)
        ctx.insert(item)
        let e1 = PriceEntry(price: wfPrice, unitPrice: unitP, unitType: unitT, date: cal.date(byAdding: .day, value: -7, to: .now)!)
        let e2 = PriceEntry(price: wmPrice, unitPrice: unitP, unitType: unitT, date: .now)
        e1.groceryItem = item; e1.store = wf
        e2.groceryItem = item; e2.store = wm
        ctx.insert(e1); ctx.insert(e2)
    }

    return PriceHistoryView().modelContainer(container)
}
