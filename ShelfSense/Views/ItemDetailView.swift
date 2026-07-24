import SwiftUI
import SwiftData
import Charts

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: GroceryItem
    @State private var isConfirmingDelete = false

    private var sortedHistory: [PriceEntry] {
        item.priceHistory.sorted { $0.date < $1.date }
    }

    private var priceColor: Color {
        guard let change = item.priceChangePercent else { return Theme.primary }
        return change > 0 ? .red : Theme.mint
    }

    private var storeCount: Int {
        Set(item.priceHistory.compactMap { $0.store?.name ?? $0.receipt?.storeName }).count
    }

    // Latest price entry per store, sorted cheapest first by unit price (or total price as fallback)
    struct StoreSnapshot {
        let storeName: String
        let price: Double
        let unitPrice: Double?
        let unitType: String?
        let isCheapest: Bool
    }

    private var storeSnapshots: [StoreSnapshot] {
        var latestByStore: [String: PriceEntry] = [:]
        for entry in item.priceHistory.sorted(by: { $0.date > $1.date }) {
            let name = entry.store?.name ?? entry.receipt?.storeName ?? ""
            guard !name.isEmpty, latestByStore[name] == nil else { continue }
            latestByStore[name] = entry
        }
        guard latestByStore.count >= 2 else { return [] }

        let snapshots = latestByStore.map { name, entry in
            StoreSnapshot(
                storeName: name,
                price: entry.price,
                unitPrice: entry.unitPrice,
                unitType: entry.unitType,
                isCheapest: false
            )
        }
        .sorted {
            // Compare by unit price when both have it; otherwise fall back to total price
            switch ($0.unitPrice, $1.unitPrice) {
            case (let a?, let b?): return a < b
            case (.some, .none):   return true
            case (.none, .some):   return false
            case (.none, .none):   return $0.price < $1.price
            }
        }

        return snapshots.enumerated().map { index, s in
            StoreSnapshot(storeName: s.storeName, price: s.price,
                          unitPrice: s.unitPrice, unitType: s.unitType, isCheapest: index == 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NavBarCurve()
                headerCard
                    .padding(.horizontal, 16)

                if !storeSnapshots.isEmpty {
                    SectionHeader(title: "Store Comparison")
                    storeComparisonCard
                        .padding(.horizontal, 16)
                }

                if sortedHistory.count >= 2 {
                    SectionHeader(title: "Price Trend")
                    priceChartCard
                        .padding(.horizontal, 16)
                }

                SectionHeader(title: "Price History")
                historyCard
                    .padding(.horizontal, 16)

                deleteButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }
        }
        .background(Theme.appBackground)
        .greenNavTitle(item.name)
        .toolbar {
            if item.isPriceAlert {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Dismiss Alert") {
                        item.lastAlertDismissedDate = .now
                    }
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Dismiss price alert for \(item.name)")
                }
            }
        }
        .alert("Delete \(item.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete Item & Price History", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(item.name) and all \(item.priceHistory.count) price record\(item.priceHistory.count == 1 ? "" : "s"). This cannot be undone.")
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Delete Item", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(Color.red.opacity(0.08))
        .foregroundStyle(.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Delete \(item.name) and all its price history")
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let price = item.latestPrice {
                    Text(price, format: .currency(code: "USD"))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .accessibilityLabel("Current price: \(price.formatted(.currency(code: "USD")))")
                } else {
                    Text("No price yet")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let change = item.priceChangePercent {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(abs(change), specifier: "%.1f")%")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(change >= 0 ? .red : Theme.mint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((change >= 0 ? Color.red : Theme.mint).opacity(0.12))
                    .clipShape(Capsule())
                    .accessibilityLabel("Price \(change >= 0 ? "up" : "down") \(abs(change), specifier: "%.1f") percent")
                }
            }

            // Unit price displayed prominently below the total price
            if let up = item.latestUnitPrice, let ut = item.latestUnitType {
                Text(String(format: up < 0.10 ? "$%.3f per %@" : "$%.2f per %@", up, ut))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(format: "Unit price: $%.2f per %@", up, ut))
            }

            HStack(spacing: 10) {
                Label(item.category, systemImage: "tag.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primary.opacity(0.08))
                    .clipShape(Capsule())

                Text("\(storeCount) store\(storeCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.secondary)

                Text("\(sortedHistory.count) scan\(sortedHistory.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if item.isPriceAlert {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Price up \(item.priceChangePercent.map { String(format: "%.0f", $0) } ?? "")% since last purchase")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .cardStyle()
    }

    // MARK: - Store Comparison Card

    private var storeComparisonCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(storeSnapshots.enumerated()), id: \.offset) { index, snapshot in
                StoreComparisonRow(snapshot: snapshot)
                if index < storeSnapshots.count - 1 {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Chart Card

    private var priceChartCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart(sortedHistory) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Price", entry.price)
                )
                .foregroundStyle(priceColor)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Price", entry.price)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [priceColor.opacity(0.18), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Price", entry.price)
                )
                .foregroundStyle(priceColor)
                .symbolSize(38)
            }
            .chartYAxis {
                AxisMarks(format: .currency(code: "USD"))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 180)
            .accessibilityLabel("Price trend chart for \(item.name)")
        }
        .cardStyle()
    }

    // MARK: - History Card

    private var historyCard: some View {
        Group {
            if sortedHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.mint)
                    Text("No price history yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedHistory.reversed().enumerated()), id: \.element.id) { index, entry in
                        PriceEntryRow(entry: entry)
                        if index < sortedHistory.count - 1 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Store Comparison Row

private struct StoreComparisonRow: View {
    let snapshot: ItemDetailView.StoreSnapshot

    private var unitLabel: String? {
        guard let up = snapshot.unitPrice, let ut = snapshot.unitType else { return nil }
        return String(format: up < 0.10 ? "$%.3f/%@" : "$%.2f/%@", up, ut)
    }

    var body: some View {
        HStack(spacing: 12) {
            StoreAvatar(name: snapshot.storeName, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.storeName)
                    .font(.subheadline.weight(.medium))
                if let label = unitLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(snapshot.price, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.bold))
                if snapshot.isCheapest {
                    Text("Best price")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.mint)
                }
            }

            if snapshot.isCheapest {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.mint)
                    .font(.body)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(snapshot.storeName), \(snapshot.price.formatted(.currency(code: "USD")))"
            + (snapshot.isCheapest ? ", best price" : "")
        )
    }
}

// MARK: - Price Entry Row

private struct PriceEntryRow: View {
    let entry: PriceEntry

    private var storeName: String {
        entry.store?.name ?? entry.receipt?.storeName ?? "Unknown Store"
    }

    // Returns the secondary detail string, or nil when nothing meaningful to add.
    // Weighted (fractional qty): "1.40 lbs @ $1.99/lb"
    // Multi-unit (integer qty > 1): "Qty: 2 · $2.99/unit"
    // Single unit where unitPrice differs from total (e.g. per-oz): "$0.059/oz"
    private var detailLine: String? {
        let qty = entry.quantity
        let isWhole = qty == floor(qty)
        let upStored = entry.unitPrice
        let ut = entry.unitType

        let showForQty = qty > 1
        let showForUnitPriceDiff = upStored.map { abs($0 - entry.price) > 0.005 } ?? false
        guard showForQty || showForUnitPriceDiff else { return nil }

        if !isWhole {
            // Fractional quantity → weighted item
            let up = upStored ?? (entry.price / max(qty, 0.001))
            let unitLabel = ut ?? "unit"
            return String(format: up < 0.10 ? "%.2f %@ @ $%.3f/%@" : "%.2f %@ @ $%.2f/%@",
                          qty, unitLabel, up, unitLabel)
        } else if qty > 1 {
            // Integer quantity > 1 → multi-unit
            let up = upStored ?? (entry.price / qty)
            let unitLabel = ut ?? "unit"
            return String(format: up < 0.10 ? "Qty: %d · $%.3f/%@" : "Qty: %d · $%.2f/%@",
                          Int(qty), up, unitLabel)
        } else {
            // Single unit where AI reported a different per-unit price (e.g. per oz)
            guard let up = upStored, let unitLabel = ut else { return nil }
            return String(format: up < 0.10 ? "$%.3f/%@" : "$%.2f/%@", up, unitLabel)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            StoreAvatar(name: storeName, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(storeName)
                    .font(.subheadline.weight(.medium))
                Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let detail = detailLine {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(entry.price, format: .currency(code: "USD"))
                .font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(storeName), \(entry.date.formatted(.dateTime.month().day().year())), \(entry.price.formatted(.currency(code: "USD")))"
            + (detailLine.map { ", \($0)" } ?? "")
        )
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
    let wf = Store(name: "Whole Foods", location: "123 Market St"); ctx.insert(wf)
    let tj = Store(name: "Trader Joe's"); ctx.insert(tj)
    let item = GroceryItem(name: "Organic Milk 64oz", normalizedName: "milk organic", category: "Dairy")
    ctx.insert(item)

    for (days, store, price, up) in [
        (-42, wf, 5.49, 0.086), (-28, wf, 5.79, 0.091),
        (-14, wf, 5.99, 0.094), (0,   wf, 6.89, 0.108),
        (-7,  tj, 5.49, 0.086),
    ] as [(Int, Store, Double, Double)] {
        let entry = PriceEntry(price: price, unitPrice: up, unitType: "oz",
                               date: cal.date(byAdding: .day, value: days, to: .now)!)
        entry.store = store; entry.groceryItem = item; ctx.insert(entry)
    }

    return NavigationStack { ItemDetailView(item: item) }.modelContainer(container)
}
