import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var receipts: [Receipt]
    @Query private var groceryItems: [GroceryItem]
    @State private var viewModel = DashboardViewModel()
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NavBarCurve()
                    heroCard
                        .padding(.horizontal, 16)

                    statChipsRow

                    if !viewModel.monthlySpends.isEmpty {
                        SectionHeader(title: "Spending Trend")
                        monthlyTrendCard.padding(.horizontal, 16)
                    }

                    if !viewModel.storeSpends.isEmpty {
                        SectionHeader(title: "By Store")
                        storeBreakdownCard.padding(.horizontal, 16)
                    }

                    if !viewModel.categorySpends.isEmpty {
                        SectionHeader(title: "By Category")
                        categoryBreakdownCard.padding(.horizontal, 16)
                    }

                    if viewModel.totalSavingsOpportunity > 0 {
                        savingsCard.padding(.horizontal, 16)
                    }

                    if !viewModel.priceAlertItems.isEmpty {
                        SectionHeader(title: "Price Alerts")
                        priceAlertsSection.padding(.horizontal, 16)
                    }

                    SectionHeader(title: "Recent Trips")
                    recentTripsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                }
            }
            .background(Theme.appBackground)
            .greenNavTitle("ShelfSense")
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { isShowingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .safeAreaPadding(.top)
            .padding(.top, 13)
            .accessibilityLabel("Open settings")
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .onChange(of: receipts, initial: true) {
            viewModel.update(receipts: receipts, groceryItems: groceryItems)
        }
        .onChange(of: groceryItems) {
            viewModel.update(receipts: receipts, groceryItems: groceryItems)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .leading) {
            Theme.heroGradient
            // Decorative blurred circles
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 180, height: 180)
                .offset(x: 200, y: -50)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 120, height: 120)
                .offset(x: 260, y: 30)

            VStack(alignment: .leading, spacing: 10) {
                Text("THIS MONTH")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .kerning(1.2)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(viewModel.monthlySpend, format: .currency(code: "USD"))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .accessibilityLabel("Monthly spend: \(viewModel.monthlySpend.formatted(.currency(code: "USD")))")

                    if let change = viewModel.monthlyChangePercent {
                        heroChangeChip(change)
                    }
                }

                Text(Date.now, format: .dateTime.month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.70))
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Theme.primary.opacity(0.35), radius: 12, x: 0, y: 4)
    }

    private func heroChangeChip(_ change: Double) -> some View {
        let isUp = change >= 0
        return HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
            Text("\(abs(change), specifier: "%.0f")%")
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(isUp ? .red : Theme.mint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.20))
        .clipShape(Capsule())
        .accessibilityLabel("Spending \(isUp ? "up" : "down") \(abs(change), specifier: "%.0f") percent vs last month")
    }

    // MARK: - Stat Chips

    private var statChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatChip(
                    icon: "receipt.fill",
                    iconColor: Theme.primary,
                    value: "\(receipts.count)",
                    label: "Receipts"
                )
                StatChip(
                    icon: "tag.fill",
                    iconColor: Theme.mint,
                    value: "\(groceryItems.count)",
                    label: "Items Tracked"
                )
                StatChip(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    value: "\(viewModel.priceAlertItems.count)",
                    label: "Price Alerts"
                )
                StatChip(
                    icon: "dollarsign.circle.fill",
                    iconColor: Theme.mint,
                    value: viewModel.totalSavingsOpportunity > 0
                        ? viewModel.totalSavingsOpportunity.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                        : "$0",
                    label: "Savings Opp."
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .accessibilityLabel("\(receipts.count) receipts, \(groceryItems.count) items tracked, \(viewModel.priceAlertItems.count) price alerts")
    }

    // MARK: - Monthly Trend

    private var monthlyTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 6 months")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.monthlySpends.allSatisfy({ $0.total == 0 }) {
                VStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(Theme.mint)
                    Text("Scan receipts to see your spending trend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            } else {
                Chart(viewModel.monthlySpends) { spend in
                    BarMark(
                        x: .value("Month", spend.label),
                        y: .value("Amount", spend.total)
                    )
                    .foregroundStyle(spend.isCurrent ? Theme.mint : Theme.primary.opacity(0.35))
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks(format: .currency(code: "USD"), values: .automatic(desiredCount: 4))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in AxisValueLabel() }
                }
                .frame(height: 160)
                .accessibilityLabel("Bar chart showing spending over the last 6 months")
            }
        }
        .cardStyle()
    }

    // MARK: - Store Breakdown

    private var storeBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All time by store")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart(viewModel.storeSpends) { store in
                SectorMark(
                    angle: .value("Amount", store.total),
                    innerRadius: .ratio(0.58),
                    outerRadius: .inset(4),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Store", store.name))
                .cornerRadius(4)
            }
            .frame(height: 180)
            .accessibilityLabel("Donut chart showing spend breakdown by store")

            VStack(spacing: 6) {
                ForEach(viewModel.storeSpends) { store in
                    HStack {
                        Text(store.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(store.total, format: .currency(code: "USD"))
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by category")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart(viewModel.categorySpends) { cat in
                BarMark(
                    x: .value("Amount", cat.total),
                    y: .value("Category", cat.category)
                )
                .foregroundStyle(Theme.mint.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(format: .currency(code: "USD"), values: .automatic(desiredCount: 4))
            }
            .frame(height: CGFloat(max(120, viewModel.categorySpends.count * 36)))
            .accessibilityLabel("Horizontal bar chart showing spend by category")
        }
        .cardStyle()
    }

    // MARK: - Savings Card

    private var savingsCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.mint.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.mint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Savings Opportunity")
                    .font(.subheadline.weight(.semibold))
                Text("per trip switching to cheapest stores")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(viewModel.totalSavingsOpportunity, format: .currency(code: "USD"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.mint)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.mint.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Savings opportunity: \(viewModel.totalSavingsOpportunity.formatted(.currency(code: "USD"))) per trip")
    }

    // MARK: - Price Alerts

    private var priceAlertsSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.priceAlertItems) { item in
                AlertItemRow(item: item)
                if item.id != viewModel.priceAlertItems.last?.id {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Recent Trips

    private var recentTripsSection: some View {
        Group {
            if viewModel.recentReceipts.isEmpty {
                emptyTripsState
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.recentReceipts) { receipt in
                        TripRow(receipt: receipt)
                        if receipt.id != viewModel.recentReceipts.last?.id {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
        }
    }

    private var emptyTripsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "receipt")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(Theme.mint)
            Text("No receipts yet")
                .font(.headline)
            Text("Scan your first receipt to start tracking prices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Subviews

private struct AlertItemRow: View {
    let item: GroceryItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                if let latest = item.latestPrice, let previous = item.previousPrice {
                    Text("\(previous, format: .currency(code: "USD")) → \(latest, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let change = item.priceChangePercent {
                Text("+\(change, specifier: "%.0f")%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), price up \(item.priceChangePercent.map { String(format: "%.0f%%", $0) } ?? "")")
    }
}

private struct TripRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            StoreAvatar(name: receipt.storeName, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.storeName)
                    .font(.subheadline.weight(.semibold))
                Text(receipt.date, format: .dateTime.month(.abbreviated).day().year())
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
        .accessibilityLabel("\(receipt.storeName), \(receipt.date.formatted(.dateTime.month().day())), \(receipt.totalAmount.formatted(.currency(code: "USD")))")
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Schema([Receipt.self, GroceryItem.self, Store.self, PriceEntry.self]),
        configurations: config
    )
    let ctx = container.mainContext
    let cal = Calendar.current

    let wf = Store(name: "Whole Foods"); ctx.insert(wf)
    let tj = Store(name: "Trader Joe's"); ctx.insert(tj)
    let cc = Store(name: "Costco"); ctx.insert(cc)

    for (monthsBack, store, total) in [
        (0, wf, 87.42), (0, tj, 64.10),
        (1, wf, 94.10), (1, cc, 191.00),
        (2, tj, 58.30), (3, wf, 102.50),
        (4, tj, 71.20), (5, cc, 185.00),
    ] as [(Int, Store, Double)] {
        let r = Receipt(
            storeName: store.name,
            date: cal.date(byAdding: .month, value: -monthsBack, to: .now)!,
            totalAmount: total
        )
        r.store = store
        ctx.insert(r)
    }

    let milk = GroceryItem(name: "Organic Milk", normalizedName: "milk organic", category: "Dairy")
    let eggs = GroceryItem(name: "Free Range Eggs", normalizedName: "eggs free range", category: "Dairy")
    ctx.insert(milk); ctx.insert(eggs)

    for (item, store, oldP, newP) in [
        (milk, wf, 5.99, 6.89), (eggs, wf, 4.49, 5.29),
    ] as [(GroceryItem, Store, Double, Double)] {
        let e1 = PriceEntry(price: oldP, date: cal.date(byAdding: .day, value: -14, to: .now)!)
        let e2 = PriceEntry(price: newP, date: .now)
        e1.groceryItem = item; e1.store = store
        e2.groceryItem = item; e2.store = store
        ctx.insert(e1); ctx.insert(e2)
    }

    return DashboardView().modelContainer(container)
}
