import SwiftUI
import SwiftData

struct PriceHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [GroceryItem]
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .unitPrice
    @State private var itemToDelete: GroceryItem?

    enum SortOrder: String, CaseIterable {
        case unitPrice = "Unit Price"
        case price     = "Price"
        case name      = "Name"
    }

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

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search items…", text: $searchText)
                .font(.body)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.top, 12)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    NavBarCurve()
                    searchBar
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
                if let item = itemToDelete {
                    modelContext.delete(item)
                }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) { itemToDelete = nil }
        } message: {
            if let item = itemToDelete {
                Text("This will permanently delete \(item.name) and all \(item.priceHistory.count) price record\(item.priceHistory.count == 1 ? "" : "s"). This cannot be undone.")
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
}

// MARK: - Item Card

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
            // Category icon
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
                // Unit price shown in gray below the total price
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = "\(item.name), \(item.category)"
        if let price = item.latestPrice {
            label += ", \(price.formatted(.currency(code: "USD")))"
        }
        if let up = item.latestUnitPrice, let ut = item.latestUnitType {
            label += ", \(String(format: "$%.2f", up)) per \(ut)"
        }
        if item.isPriceAlert, let change = item.priceChangePercent {
            label += ", price alert: up \(String(format: "%.0f", change)) percent"
        }
        return label
    }

    private func categoryIcon(_ category: String) -> String {
        switch category.lowercased() {
        case "dairy":    return "drop.fill"
        case "bakery":   return "birthday.cake.fill"
        case "produce":  return "leaf.fill"
        case "meat & seafood": return "flame.fill"
        case "pantry":   return "cabinet.fill"
        case "beverages": return "cup.and.saucer.fill"
        case "snacks & frozen": return "snowflake"
        case "household": return "house.fill"
        default:         return "cart.fill"
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
    let wf = Store(name: "Whole Foods"); ctx.insert(wf)

    for (name, category, old, new, unitPrice, unitType) in [
        ("Organic Milk 64oz", "Dairy",   5.99, 6.89, 0.108, "oz"),
        ("Sourdough Bread",   "Bakery",  4.49, 4.49, nil,   nil as String?),
        ("Free Range Eggs 12ct", "Dairy",4.99, 5.79, 0.483, "ea"),
        ("Baby Spinach 5oz",  "Produce", 3.99, 3.99, 0.798, "oz"),
        ("Olive Oil 16.9 fl oz", "Pantry", 12.99, 15.49, 0.916, "fl oz"),
    ] as [(String, String, Double, Double, Double?, String?)] {
        let item = GroceryItem(name: name, normalizedName: ItemMatcher.normalize(name), category: category)
        ctx.insert(item)
        let e1 = PriceEntry(price: old, unitPrice: unitPrice, unitType: unitType,
                            date: cal.date(byAdding: .day, value: -14, to: .now)!)
        let e2 = PriceEntry(price: new, unitPrice: unitPrice, unitType: unitType, date: .now)
        e1.groceryItem = item; e1.store = wf
        e2.groceryItem = item; e2.store = wf
        ctx.insert(e1); ctx.insert(e2)
    }

    return PriceHistoryView().modelContainer(container)
}
