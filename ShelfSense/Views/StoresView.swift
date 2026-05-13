import SwiftUI
import SwiftData

struct StoresView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Store.name) private var stores: [Store]
    @Query private var groceryItems: [GroceryItem]
    @State private var viewModel = StoresViewModel()
    @State private var storeToDelete: Store?

    var body: some View {
        NavigationStack {
            Group {
                if stores.isEmpty {
                    emptyState
                } else {
                    storesList
                }
            }
            .greenNavTitle("Stores")
        }
        .onChange(of: groceryItems, initial: true) {
            viewModel.update(groceryItems: groceryItems)
        }
        .alert(
            "Delete \(storeToDelete?.name ?? "Store")?",
            isPresented: Binding(get: { storeToDelete != nil }, set: { if !$0 { storeToDelete = nil } })
        ) {
            Button("Delete Store & All Trips", role: .destructive) {
                storeToDelete?.deleteWithCascade(from: modelContext)
                storeToDelete = nil
            }
            Button("Cancel", role: .cancel) { storeToDelete = nil }
        } message: {
            if let store = storeToDelete {
                let count = store.receipts.count
                Text("This will permanently delete \(store.name) and \(count) trip\(count == 1 ? "" : "s") with all price data. This cannot be undone.")
            }
        }
    }

    // MARK: - Stores List

    private var storesList: some View {
        ScrollView {
            VStack(spacing: 16) {
                NavBarCurve()
                if !viewModel.itemComparisons.isEmpty {
                    savingsHeroCard
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    SectionHeader(title: "Best Deals")
                    bestDealsCard
                        .padding(.horizontal, 16)
                }

                SectionHeader(title: "Your Stores")
                VStack(spacing: 10) {
                    ForEach(stores) { store in
                        NavigationLink(destination: StoreDetailView(store: store)) {
                            StoreCard(store: store)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                storeToDelete = store
                            } label: {
                                Label("Delete Store", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .background(Theme.appBackground)
    }

    // MARK: - Savings Hero Card

    private var savingsHeroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 56, height: 56)
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Potential Savings")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(viewModel.totalPotentialSavings, format: .currency(code: "USD"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("per trip at cheapest stores")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
        }
        .padding(20)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Theme.primary.opacity(0.30), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated savings: \(viewModel.totalPotentialSavings.formatted(.currency(code: "USD"))) per trip")
    }

    // MARK: - Best Deals Card

    private var bestDealsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.itemComparisons.prefix(5).enumerated()), id: \.element.id) { index, comparison in
                DealRow(comparison: comparison)
                if index < min(4, viewModel.itemComparisons.count - 1) {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack(alignment: .top) {
            Theme.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                NavBarCurve()
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(Theme.mint)
                    Text("No stores yet")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Stores appear automatically after you scan your first receipt.")
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
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Store Card

private struct StoreCard: View {
    let store: Store

    private var totalSpend: Double { store.receipts.reduce(0) { $0 + $1.totalAmount } }

    var body: some View {
        HStack(spacing: 14) {
            StoreAvatar(name: store.name, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.label))
                HStack(spacing: 4) {
                    Text("\(store.receipts.count) trip\(store.receipts.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !store.location.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(store.location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(totalSpend, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.label))
                Text("total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
        .accessibilityLabel("\(store.name), \(store.receipts.count) trips, total \(totalSpend.formatted(.currency(code: "USD")))")
    }
}

// MARK: - Deal Row

private struct DealRow: View {
    let comparison: StoresViewModel.ItemComparison

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.mint.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.body)
                    .foregroundStyle(Theme.mint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(comparison.itemName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Text(comparison.cheapestStore)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let text = comparison.unitComparisonText {
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(comparison.cheapestPrice, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.mint)
                Text("save \(comparison.savings, format: .currency(code: "USD"))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.mint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(comparison.itemName), cheapest at \(comparison.cheapestStore) for \(comparison.cheapestPrice.formatted(.currency(code: "USD"))), saves \(comparison.savings.formatted(.currency(code: "USD")))")
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

    let wf = Store(name: "Whole Foods", location: "123 Market St")
    let tj = Store(name: "Trader Joe's", location: "456 Oak Ave")
    let cc = Store(name: "Costco", location: "789 Warehouse Blvd")
    ctx.insert(wf); ctx.insert(tj); ctx.insert(cc)

    for (store, total) in [(wf, 87.42), (wf, 94.10), (tj, 64.10), (cc, 191.00)] {
        let r = Receipt(
            storeName: store.name,
            date: cal.date(byAdding: .day, value: -Int.random(in: 1...30), to: .now)!,
            totalAmount: total
        )
        r.store = store; ctx.insert(r)
    }

    let milk = GroceryItem(name: "Organic Milk", normalizedName: "milk organic", category: "Dairy")
    ctx.insert(milk)
    for (store, price) in [(wf, 6.89), (tj, 5.99), (cc, 5.49)] {
        let e = PriceEntry(price: price, date: .now)
        e.store = store; e.groceryItem = milk; ctx.insert(e)
    }

    return StoresView().modelContainer(container)
}
