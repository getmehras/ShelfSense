import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var receipts: [Receipt]
    @Query private var groceryItems: [GroceryItem]
    @State private var viewModel = DashboardViewModel()
    @State private var isShowingSettings = false
    @State private var isShowingTrendDetail = false
    @AppStorage("selected_tab")        private var selectedTab = 0
    @AppStorage("price_compare_active")  private var priceCompareActive = false
    @AppStorage("price_alert_item_id")   private var alertItemID: String = ""
    @AppStorage("monthly_budget")        private var monthlyBudget: Double = 0

    private var allSavingsOpportunities: [PriceComparisonViewModel.SavingsOpportunity] {
        PriceComparisonViewModel.topSavingsOpportunities(from: groceryItems, limit: 10)
    }

    private var totalCorrectSavings: Double {
        allSavingsOpportunities.reduce(0) { $0 + $1.savings }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NavBarCurve()
                    heroCard
                        .padding(.horizontal, 16)

                    if monthlyBudget > 0 {
                        budgetProgressCard
                            .padding(.horizontal, 16)
                        if let projected = viewModel.projectedMonthTotal {
                            spendPredictionRow(projected: projected)
                                .padding(.horizontal, 16)
                        }
                    }

                    statChipsRow

                    if !viewModel.priceAlertItems.isEmpty {
                        Text("Price Alerts")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        priceAlertsSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    if totalCorrectSavings > 0 {
                        unifiedSavingsCard.padding(.horizontal, 16)
                    }

                    if !viewModel.monthlySpends.isEmpty {
                        SectionHeader(title: "Spending Trend")
                        monthlyTrendCard.padding(.horizontal, 16)
                    }

                    if !viewModel.storeSpends.isEmpty {
                        SectionHeader(title: "By Store")
                        storeBreakdownCard.padding(.horizontal, 16)
                    }

                    SectionHeader(title: "Recent Trips")
                    recentTripsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                }
            }
            .background(Theme.appBackground)
            .scrollContentBackground(.hidden)
            .toolbarBackground(Color(red: 27/255, green: 94/255, blue: 32/255), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        .fullScreenCover(isPresented: $isShowingTrendDetail) {
            SpendingTrendDetailView(monthlySpends: viewModel.historicalMonthlySpends)
        }
        .onChange(of: receipts, initial: true) {
            viewModel.update(receipts: receipts, groceryItems: groceryItems)
        }
        .onChange(of: groceryItems) {
            viewModel.update(receipts: receipts, groceryItems: groceryItems)
        }
    }

    // MARK: - Budget Progress Card

    @ViewBuilder
    private var budgetProgressCard: some View {
        let spent  = viewModel.monthlySpend
        let budget = monthlyBudget
        let pct    = min(spent / budget, 1.0)
        let status = viewModel.budgetStatus(for: budget)
        let fillColor: Color = status == .exceeded ? .red
                             : status == .approaching ? .orange
                             : Theme.mint

        VStack(alignment: .leading, spacing: 10) {
            Text("MONTHLY BUDGET")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(1.0)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fillColor)
                        .frame(width: max(geo.size.width * CGFloat(pct), pct > 0 ? 8 : 0), height: 8)
                }
            }
            .frame(height: 8)

            if status == .exceeded {
                let overage = spent - budget
                Text("\(spent.formatted(.currency(code: "USD"))) of \(budget.formatted(.currency(code: "USD"))) — \(overage.formatted(.currency(code: "USD"))) over budget")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            } else {
                Text("\(spent.formatted(.currency(code: "USD"))) of \(budget.formatted(.currency(code: "USD"))) spent this month")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(fillColor.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            status == .exceeded
                ? "Over budget: spent \(spent.formatted(.currency(code: "USD"))) of \(budget.formatted(.currency(code: "USD"))) monthly budget"
                : "Budget: \(spent.formatted(.currency(code: "USD"))) of \(budget.formatted(.currency(code: "USD"))) spent this month"
        )
    }

    // MARK: - Spend Prediction Row

    private func spendPredictionRow(projected: Double) -> some View {
        let budgetSet = monthlyBudget > 0
        let overBudget = budgetSet && projected > monthlyBudget
        let approaching = budgetSet && !overBudget && projected >= monthlyBudget * 0.80

        let accentColor: Color = overBudget ? .red : approaching ? .orange : .secondary

        let label: String = {
            let projStr = projected.formatted(.currency(code: "USD"))
            if budgetSet {
                let budgetStr = monthlyBudget.formatted(.currency(code: "USD"))
                if overBudget {
                    let over = (projected - monthlyBudget).formatted(.currency(code: "USD"))
                    return "On pace to spend \(projStr) — \(over) over your \(budgetStr) budget"
                } else {
                    return "On pace to spend \(projStr) this month (\(budgetStr) budget)"
                }
            }
            return "On pace to spend \(projStr) this month"
        }()

        return HStack(spacing: 8) {
            Image(systemName: overBudget ? "exclamationmark.circle.fill" : "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(accentColor)
            Text(label)
                .font(.caption)
                .foregroundStyle(budgetSet ? accentColor : Color(.secondaryLabel))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel(label)
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .accessibilityLabel("\(receipts.count) receipts, \(groceryItems.count) items tracked, \(viewModel.priceAlertItems.count) price alerts")
    }

    // MARK: - Monthly Trend

    private var monthlyTrendCard: some View {
        Button {
            isShowingTrendDetail = true
        } label: {
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
                    SpendingBarChart(data: viewModel.monthlySpends, height: 160)
                        .allowsHitTesting(false)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
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

    // MARK: - Unified Savings Card

    private var unifiedSavingsCard: some View {
        Button {
            selectedTab = 3
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.mint.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.mint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Save up to \(totalCorrectSavings.formatted(.currency(code: "USD"))) this trip")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(.label))
                    let count = allSavingsOpportunities.count
                    Text("\(count) deal\(count == 1 ? "" : "s") found · potential savings per trip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(16)
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    Theme.mint.opacity(0.08)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.mint.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Save up to \(totalCorrectSavings.formatted(.currency(code: "USD"))) this trip, \(allSavingsOpportunities.count) deals found. Tap to view in Stores tab.")
    }

    // MARK: - Price Alerts

    private var priceAlertsSection: some View {
        let items = viewModel.priceAlertItems
        let isSingle = items.count == 1
        return Button {
            if isSingle, let item = items.first {
                alertItemID = item.name
            }
            selectedTab = 2
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    if isSingle, let item = items.first {
                        Text("\(item.name) price increased\(item.priceChangePercent.map { String(format: " +%.0f%%", $0) } ?? "")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                        Text("tap to view price history")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(items.count) price changes since your last scan")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                        Text("tap to review in Price History")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(16)
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    Color.orange.opacity(0.08)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isSingle
                ? "\(items.first?.name ?? ""), price up \(items.first?.priceChangePercent.map { String(format: "%.0f%%", $0) } ?? ""). Tap to view price history."
                : "\(items.count) price changes since your last scan. Tap to review in Price History."
        )
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
                        Divider().padding(.horizontal, 16)
                    }
                    Button {
                        selectedTab = 3
                    } label: {
                        HStack {
                            Text("See All Trips")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.mint)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.mint)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color(.secondarySystemGroupedBackground))
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Subviews

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
